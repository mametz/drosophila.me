require "test_helper"

class LegacyImportTest < ActiveSupport::TestCase
  self.use_transactional_tests = true

  HASH = BCrypt::Password.create("old-password", cost: 4).to_s

  setup do
    Session.delete_all
    User.delete_all
    @conn = ActiveRecord::Base.connection
    @conn.execute("CREATE SCHEMA legacy")
    @conn.execute(<<~SQL)
      CREATE TABLE legacy.users (id int primary key, email text, encrypted_password text, created_at timestamp, updated_at timestamp);
      CREATE TABLE legacy.rooms (id int primary key, name text, temperature int, user_id int, created_at timestamp, updated_at timestamp);
      CREATE TABLE legacy.flies (id int primary key, chr1 text, chr2 text, chr3 text, chr4 text, cross_id int, created_at timestamp, updated_at timestamp);
      CREATE TABLE legacy.crosses (id int primary key, male_id int, female_id int, link text, slug text, description text, balancers text, lethal text, parent int, user_id int, crossdate date, created_at timestamp, updated_at timestamp);
      CREATE TABLE legacy.stocks (id int primary key, number int, name text, fly_id int, user_id int, comment text, date_established date, room_id int, reference text, received_from text, created_at timestamp, updated_at timestamp);
    SQL
    now = "'2020-01-02 03:04:05'"
    @conn.execute(<<~SQL)
      INSERT INTO legacy.users VALUES (7, ' Lab@Example.com ', '#{HASH}', #{now}, #{now}), (9, 'other@example.com', '#{HASH}', #{now}, #{now});
      INSERT INTO legacy.rooms VALUES (3, '18C', 18, 7, #{now}, #{now}), (4, 'theirs', 25, 9, #{now}, #{now});
      INSERT INTO legacy.flies VALUES
        (100, 'w/-', 'Cy/+', '+/+', '+/+', 50, #{now}, #{now}),
        (101, 'w/w', '+/+', '+/+', '+/+', 50, #{now}, #{now}),
        (102, '/w', 'Cy/+', '+/+', '+/+', 50, #{now}, #{now}),
        (103, 'a/b/c', '+/+', '', '+/+', 0, #{now}, #{now}),
        (104, NULL, '+/+', '+/+', '+/+', 50, #{now}, #{now}),
        (105, 'w/w', '+/+', '+/+', '+/+', 999, #{now}, #{now}),
        (106, 'w/w', '+/+', '+/+', '+/+', 999, #{now}, #{now});
      INSERT INTO legacy.crosses VALUES
        (50, 100, 101, 'abc', 'slug-a', 'first', 'CyO', 'x', 0, 7, '2016-05-06', #{now}, #{now}),
        (51, 100, 101, 'def', 'slug-b', 'child', '', '', 50, 7, '2016-06-07', #{now}, #{now}),
        (52, 100, 101, NULL, 'slug-c', 'orphaned', '', '', 8888, 7, '2016-06-07', #{now}, #{now}),
        (53, NULL, NULL, 'x', 'slug-d', 'crashed on create', '', '', NULL, 7, '2016-06-07', #{now}, #{now}),
        (54, 100, 7777, 'y', 'slug-e', 'parent fly gone', '', '', NULL, 7, '2016-06-07', #{now}, #{now}),
        (55, 100, 101, NULL, 'slug-f', 'loop', '', '', 55, 7, '2016-06-07', #{now}, #{now}),
        (56, 100, 101, 'z', 'slug-g', 'child of skipped', '', '', 53, 7, '2016-06-07', #{now}, #{now});
      INSERT INTO legacy.stocks VALUES
        (1, 4, 'a', 103, 7, 'keep', '2016-01-01', 3, 'ref', 'from', #{now}, #{now}),
        (2, 5, 'b', 100, 7, NULL, NULL, 4, NULL, NULL, #{now}, #{now}),
        (3, 6, 'c', 100, 7, NULL, NULL, 99, NULL, NULL, #{now}, #{now}),
        (4, 7, 'd', 7777, 7, NULL, NULL, NULL, NULL, NULL, #{now}, #{now});
    SQL
  end

  def import(**options)
    out = StringIO.new
    importer = LegacyImport.new(source: @conn, schema: "legacy", out: out)
    importer.run(**options)
    [ importer, out.string ]
  end

  test "keeps ids, slugs, normalized emails and timestamps" do
    import
    user = User.find(7)
    assert_equal "lab@example.com", user.email_address
    assert_equal Time.utc(2020, 1, 2, 3, 4, 5), user.created_at

    cross = Cross.find_by!(slug: "slug-a")
    assert_equal 50, cross.id
    assert_equal user, cross.user
    assert_equal Date.new(2016, 5, 6), cross.crossdate
    assert_equal 100, cross.male_fly_id
    assert_equal 101, cross.female_fly_id
    assert cross.shared?
  end

  test "leaves out only accounts that never created anything" do
    @conn.execute(<<~SQL)
      INSERT INTO legacy.users VALUES
        (10, 'stock-only@example.com', '#{HASH}', '2020-01-01', '2020-01-01'),
        (11, 'broken-cross-only@example.com', '#{HASH}', '2020-01-01', '2020-01-01'),
        (12, 'nothing@example.com', '#{HASH}', '2020-01-01', '2020-01-01');
      INSERT INTO legacy.stocks VALUES (5, 1, 'x', 100, 10, NULL, NULL, NULL, NULL, NULL, '2020-01-01', '2020-01-01');
      INSERT INTO legacy.crosses VALUES (57, NULL, NULL, 'q', 'slug-q', 'crashed', '', '', NULL, 11, '2016-06-07', '2020-01-01', '2020-01-01');
    SQL
    importer, output = import

    assert User.exists?(7)
    assert User.exists?(10)
    assert User.exists?(9), "has a room"
    assert Room.exists?(4)
    assert User.exists?(11), "has a cross, even though it can't be imported"
    assert_not Cross.exists?(57)
    assert_not User.exists?(12)
    assert_equal 1, importer.counts[:accounts_without_any_data]
    assert_equal 0, importer.counts[:rooms_skipped]
    assert_includes output, "accounts without any data: 1"
  end

  test "imported users log in with their old password" do
    import
    assert User.authenticate_by(email_address: "lab@example.com", password: "old-password")
    assert_nil User.authenticate_by(email_address: "lab@example.com", password: "wrong")
  end

  test "skips crosses with unusable parents and reports their ids" do
    importer, output = import
    assert_equal [ 53, 54 ], importer.skipped_cross_ids.sort
    assert_not Cross.exists?(53)
    assert_includes output, "Skipped cross ids: 53, 54"
    assert_not_includes output, "lab@example.com"
  end

  test "clears parents that are missing, skipped or the cross itself" do
    importer, = import
    assert_equal 50, Cross.find(51).parent_id
    assert_nil Cross.find(52).parent_id
    assert_nil Cross.find(55).parent_id
    assert_nil Cross.find(56).parent_id
    assert_equal 3, importer.counts[:parents_cleared]
  end

  test "drops unreachable flies and keeps those a stock or cross still uses" do
    import
    assert Fly.exists?(103)
    assert_nil Fly.find(103).cross_id
    assert_equal "a/b/c", Fly.find(103).chr1
    assert_equal "/w", Fly.find(102).chr1
    assert_not Fly.exists?(104)
    assert_not Fly.exists?(105)
    assert_equal [ 102 ], Cross.find(50).progeny.map(&:id)
  end

  test "stocks keep their details, and lose rooms that aren't theirs" do
    importer, = import
    stock = Stock.find(1)
    assert_equal [ 4, "keep", 3, "ref", "from" ], [ stock.number, stock.comment, stock.room_id, stock.reference, stock.received_from ]
    assert_nil Stock.find(2).room_id
    assert_nil Stock.find(3).room_id
    assert_not Stock.exists?(4)
    assert_equal 2, importer.counts[:stock_rooms_cleared]
    assert_equal 1, importer.counts[:stocks_skipped]
  end

  test "new records continue after the imported ids" do
    import
    room = User.find(7).rooms.create!(name: "new")
    assert_operator room.id, :>, 4
    assert_operator Cross.create!(user: User.find(7), crossdate: Date.current).id, :>, 56
  end

  test "dry run saves nothing" do
    _, output = import(dry_run: true)
    assert_includes output, "DRY RUN"
    assert_equal 0, User.count
    assert_equal 0, Cross.count
  end

  test "refuses to run on a database that already has data" do
    User.create!(email_address: "here@example.com", password: "password123")
    error = assert_raises(ArgumentError) { import }
    assert_includes error.message, "already has data"
  end

  test "refuses a source with missing columns" do
    @conn.execute("ALTER TABLE legacy.crosses DROP COLUMN slug")
    error = assert_raises(ArgumentError) { import }
    assert_includes error.message, "slug"
  end
end
