# Copies data from a restored dump of the old Rails 4.2 database into this schema,
# keeping ids and slugs. Rows the old app could not display are skipped and listed.
# So are accounts that never created a cross, stock or room, which are mostly signup spam.
class LegacyImport
  class Source < ActiveRecord::Base
    self.abstract_class = true
  end

  BATCH_SIZE = 2000
  REQUIRED_COLUMNS = {
    "users" => %w[id email encrypted_password created_at updated_at],
    "rooms" => %w[id name temperature user_id created_at updated_at],
    "flies" => %w[id chr1 chr2 chr3 chr4 cross_id created_at updated_at],
    "crosses" => %w[id male_id female_id link slug description balancers lethal parent user_id crossdate created_at updated_at],
    "stocks" => %w[id number name fly_id user_id comment date_established room_id reference received_from created_at updated_at]
  }.freeze

  attr_reader :counts, :skipped_cross_ids

  def self.connect(url)
    Source.establish_connection(url)
    new(source: Source.connection)
  end

  def initialize(source:, schema: nil, out: $stdout)
    @source = source
    @schema = schema
    @out = out
    @counts = Hash.new(0)
    @skipped_cross_ids = []
  end

  def run(dry_run: false)
    check_source
    refuse_if_target_has_data

    ActiveRecord::Base.transaction(requires_new: true) do
      import
      verify
      raise ActiveRecord::Rollback if dry_run
    end
    reset_sequences unless dry_run
    report(dry_run)
    self
  end

  private

  def rows(table)
    @source.select_all("SELECT * FROM #{qualified(table)} ORDER BY id").to_a
  end

  def qualified(table)
    [ @schema, table ].compact.map { |part| @source.quote_table_name(part) }.join(".")
  end

  def check_source
    REQUIRED_COLUMNS.each do |table, columns|
      found = @source.select_values(<<~SQL.squish)
        SELECT column_name FROM information_schema.columns
        WHERE table_name = #{@source.quote(table)} AND table_schema = #{@source.quote(@schema || "public")}
      SQL
      missing = columns - found
      raise ArgumentError, "Legacy table #{table} is missing columns: #{missing.join(", ")}" if missing.any?
    end
  end

  def refuse_if_target_has_data
    return unless User.exists? || Cross.exists? || Fly.exists?

    raise ArgumentError, "This database already has data. The import only runs on an empty one."
  end

  def import
    users = rows("users")
    rooms = rows("rooms")
    flies = rows("flies")
    crosses = rows("crosses")
    stocks = rows("stocks")

    user_ids = users.map { |row| row["id"] }.to_set
    usable_fly_ids = flies.select { |row| complete_fly?(row) }.map { |row| row["id"] }.to_set
    @counts[:flies_without_chromosomes] = flies.size - usable_fly_ids.size

    kept_crosses, dropped_crosses = crosses.partition do |row|
      user_ids.include?(row["user_id"]) && usable_fly_ids.include?(row["male_id"]) && usable_fly_ids.include?(row["female_id"])
    end
    @skipped_cross_ids = dropped_crosses.map { |row| row["id"] }
    kept_cross_ids = kept_crosses.map { |row| row["id"] }.to_set

    kept_stocks, dropped_stocks = stocks.partition do |row|
      user_ids.include?(row["user_id"]) && usable_fly_ids.include?(row["fly_id"])
    end
    @counts[:stocks_skipped] = dropped_stocks.size

    kept_flies = flies_to_keep(flies, usable_fly_ids, kept_crosses, kept_stocks, kept_cross_ids)

    # Counts every cross, so an account whose crosses are all skipped can still log in.
    active_user_ids = (crosses + stocks + rooms).map { |row| row["user_id"] }.to_set
    kept_users = users.select { |row| active_user_ids.include?(row["id"]) }
    @counts[:accounts_without_any_data] = users.size - kept_users.size

    import_users(kept_users)
    import_rooms(rooms, active_user_ids)
    import_crosses(kept_crosses)
    import_flies(kept_flies, kept_cross_ids)
    link_crosses(kept_crosses, kept_cross_ids)
    import_stocks(kept_stocks)
  end

  def complete_fly?(row)
    row["chr1"] && row["chr2"] && row["chr3"] && row["chr4"]
  end

  # Flies whose cross was deleted are unreachable unless a stock or cross still uses them.
  def flies_to_keep(flies, usable_fly_ids, crosses, stocks, cross_ids)
    used = crosses.flat_map { |row| [ row["male_id"], row["female_id"] ] }.to_set
    stocks.each { |row| used << row["fly_id"] }

    kept = flies.select do |row|
      usable_fly_ids.include?(row["id"]) && (cross_ids.include?(row["cross_id"]) || used.include?(row["id"]))
    end
    @counts[:unreachable_flies_skipped] = usable_fly_ids.size - kept.size
    kept
  end

  def import_users(rows)
    insert(User, rows.map do |row|
      { id: row["id"], email_address: row["email"].strip.downcase, password_digest: row["encrypted_password"],
        created_at: row["created_at"], updated_at: row["updated_at"] }
    end)
  end

  def import_rooms(rows, user_ids)
    kept = rows.select { |row| user_ids.include?(row["user_id"]) }
    @counts[:rooms_skipped] = rows.size - kept.size
    insert(Room, kept.map do |row|
      { id: row["id"], name: row["name"].presence || "Room #{row["id"]}", temperature: row["temperature"],
        user_id: row["user_id"], created_at: row["created_at"], updated_at: row["updated_at"] }
    end)
    @room_owners = kept.to_h { |row| [ row["id"], row["user_id"] ] }
  end

  def import_crosses(rows)
    insert(Cross, rows.map do |row|
      { id: row["id"], user_id: row["user_id"], slug: row["slug"].presence || row["link"].presence || SecureRandom.hex,
        description: row["description"], balancers: row["balancers"].to_s, lethal: row["lethal"].to_s,
        crossdate: row["crossdate"] || row["created_at"].to_s[0, 10], shared: true,
        created_at: row["created_at"], updated_at: row["updated_at"] }
    end)
  end

  def import_flies(rows, cross_ids)
    insert(Fly, rows.map do |row|
      { id: row["id"], chr1: row["chr1"], chr2: row["chr2"], chr3: row["chr3"], chr4: row["chr4"],
        cross_id: cross_ids.include?(row["cross_id"]) ? row["cross_id"] : nil,
        created_at: row["created_at"], updated_at: row["updated_at"] }
    end)
  end

  # Crosses and flies point at each other, so these links are set after both exist.
  def link_crosses(rows, cross_ids)
    rows.each do |row|
      parent = row["parent"].to_i
      parent_id = parent != row["id"] && cross_ids.include?(parent) ? parent : nil
      @counts[:parents_cleared] += 1 if parent >= 1 && parent_id.nil?
      Cross.where(id: row["id"]).update_all(male_fly_id: row["male_id"], female_fly_id: row["female_id"], parent_id: parent_id)
    end
  end

  def import_stocks(rows)
    insert(Stock, rows.map do |row|
      room_id = row["room_id"]
      if room_id && @room_owners[room_id] != row["user_id"]
        @counts[:stock_rooms_cleared] += 1
        room_id = nil
      end
      { id: row["id"], number: row["number"], name: row["name"], fly_id: row["fly_id"], user_id: row["user_id"],
        room_id: room_id, comment: row["comment"], date_established: row["date_established"],
        reference: row["reference"], received_from: row["received_from"],
        created_at: row["created_at"], updated_at: row["updated_at"] }
    end)
  end

  def insert(model, attributes)
    attributes.each_slice(BATCH_SIZE) { |slice| model.insert_all!(slice, record_timestamps: false) }
    @counts[model.table_name.to_sym] = attributes.size
  end

  def verify
    missing = Cross.where(male_fly_id: nil).or(Cross.where(female_fly_id: nil)).count
    raise "#{missing} imported crosses have no parents" if missing.positive?

    { User => :users, Room => :rooms, Fly => :flies, Cross => :crosses, Stock => :stocks }.each do |model, key|
      raise "#{model} count is #{model.count}, expected #{@counts[key]}" unless model.count == @counts[key]
    end
  end

  def reset_sequences
    %w[users rooms flies crosses stocks].each { |table| ActiveRecord::Base.connection.reset_pk_sequence!(table) }
  end

  def report(dry_run)
    @out.puts(dry_run ? "DRY RUN, nothing was saved." : "Import finished.")
    %i[users rooms crosses flies stocks].each { |key| @out.puts "  #{key}: #{@counts[key]}" }
    @out.puts "Skipped or changed:"
    @out.puts "  crosses without usable parents: #{@skipped_cross_ids.size}"
    %i[accounts_without_any_data parents_cleared flies_without_chromosomes unreachable_flies_skipped stocks_skipped rooms_skipped stock_rooms_cleared].each do |key|
      @out.puts "  #{key.to_s.tr("_", " ")}: #{@counts[key]}"
    end
    @out.puts "Skipped cross ids: #{@skipped_cross_ids.join(", ")}" if @skipped_cross_ids.any?
  end
end
