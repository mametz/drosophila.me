# Sets up a new cross and its progeny from the cross form. Parents come from
# typed genotypes, chromosomes picked from a previous cross, or existing flies.
class CrossBuilder
  CHROMOSOME_NAMES = %i[X II III IV].freeze
  ALLELES = %r{\A[^/]+(/[^/]+)?\z}

  attr_reader :cross, :errors

  def initialize(user:, params:)
    @user = user
    @params = params
    @errors = []
  end

  def save
    date = @params.select { |key, _| key.start_with?("crossdate") }
    @cross = Cross.new(@params.slice(:description, :balancers, :lethal).merge(date))
    @cross.user = @user
    @cross.parent = parent_cross if follow_on? && @params[:parent] != "stock"
    @errors << "That cross was not found." if follow_on? && @params[:parent] != "stock" && @cross.parent.nil?

    male, female = parents
    return false if @errors.any?

    Cross.transaction do
      @cross.save!
      male = save_parent(male)
      female = save_parent(female)
      # Parents from the old app can hold chromosomes such as "/w", so the
      # progeny they produce can't pass the check for typed genotypes. The
      # parents' X chromosomes were checked above, so no Y/Y fly can come out.
      CrossCalculator.progeny(male.chromosomes, female.chromosomes).each do |chromosomes|
        Fly.from_chromosomes(chromosomes, cross: @cross).save!(validate: false)
      end
      @cross.update!(male_fly: male, female_fly: female)
    end
    true
  rescue ActiveRecord::RecordInvalid, ActiveRecord::MultiparameterAssignmentErrors => e
    @errors << e.message
    false
  end

  private

  def follow_on?
    @params[:parent].to_s == "stock" || @params[:parent].to_i >= 1
  end

  def parent_cross
    @user.crosses.find_by(id: @params[:parent])
  end

  def parents
    if follow_on?
      [ selected_parent(:male_id, "male_chr_s", "m", :male), selected_parent(:female_id, "female_chr_s", "f", :female) ]
    else
      [ typed(names("m"), :male), typed(names("f"), :female) ]
    end
  end

  def selected_parent(key, chromosomes_choice, prefix, sex)
    choice = @params[key].presence
    case choice
    when nil
      @errors << "Not all parents were selected."
      nil
    when "new"
      typed(CHROMOSOME_NAMES, sex)
    when chromosomes_choice
      picked(names(prefix), sex)
    else
      existing_fly(choice, sex)
    end
  end

  def names(prefix)
    CHROMOSOME_NAMES.map { |name| :"#{prefix}_#{name}" }
  end

  def typed(fields, sex)
    values = fields.map { |field| @params[field].to_s.strip }
    unless values.all? { |value| value.match?(ALLELES) }
      @errors << "Genotypes need one or two alleles per chromosome, separated by a slash."
      return nil
    end

    build_fly(values, sex)
  end

  # Picked from the chromosomes of a previous cross, so old notation is allowed.
  def picked(fields, sex)
    values = fields.map { |field| @params[field].to_s }
    if values.any?(&:blank?)
      @errors << "Not all chromosomes were selected."
      return nil
    end

    build_fly(values, sex)
  end

  def build_fly(values, sex)
    x = checked_x(values[0], sex)
    return nil unless x

    Fly.from_chromosomes([ x, *values[1..] ].map { |value| Genotype.homozygous(value) })
  end

  # Only flies the user can reach through their own crosses or stocks.
  def existing_fly(id, sex)
    fly = Fly.find_by(id: id)
    unless fly && @user.can_use_fly?(fly)
      @errors << "That fly was not found."
      return nil
    end

    x = checked_x(fly.chr1, sex)
    return nil unless x

    unless fly.chromosomes[1..].all? { |chromosome| chromosome.split("/").size >= 2 } && x.split("/").size >= 2
      @errors << "That fly has an incomplete genotype. Enter it as a new genotype to cross it."
      return nil
    end

    # Old records can hold a male written as "w/w". Keep the record and use a
    # corrected copy of the fly for this cross.
    x == fly.chr1 ? fly : Fly.from_chromosomes([ x, *fly.chromosomes[1..] ])
  end

  def checked_x(x, sex)
    if sex == :male
      return Genotype.male_x(x) if Genotype.valid_male_x?(x)

      @errors << "A male has one X chromosome, such as w/- or w/Y. #{x} doesn't fit, so choose a son or enter the male again."
    else
      return x if Genotype.valid_female_x?(x)

      @errors << "A female has two X chromosomes and no Y. #{x} doesn't fit, so choose a daughter or enter the female again."
    end
    nil
  end

  def save_parent(fly)
    return fly if fly.persisted?

    fly.cross = @cross
    fly.save!(validate: false)
    fly
  end
end
