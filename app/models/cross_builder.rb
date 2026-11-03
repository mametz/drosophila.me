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
      # progeny they produce can't pass the check for typed genotypes.
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
      [ selected_parent(:male_id, "male_chr_s", "m"), selected_parent(:female_id, "female_chr_s", "f") ]
    else
      [ typed(names("m"), founder_male: true), typed(names("f")) ]
    end
  end

  def selected_parent(key, chromosomes_choice, prefix)
    choice = @params[key].presence
    case choice
    when nil
      @errors << "Not all parents were selected."
      nil
    when "new"
      typed(CHROMOSOME_NAMES, male: prefix == "m")
    when chromosomes_choice
      picked(names(prefix))
    else
      existing_fly(choice)
    end
  end

  def names(prefix)
    CHROMOSOME_NAMES.map { |name| :"#{prefix}_#{name}" }
  end

  def typed(fields, founder_male: false, male: false)
    values = fields.map { |field| @params[field].to_s.strip }
    unless values.all? { |value| value.match?(ALLELES) }
      @errors << "Genotypes need one or two alleles per chromosome, separated by a slash."
      return nil
    end
    if founder_male && values[0] == "Y"
      @errors << "A male X chromosome needs an allele next to the Y."
      return nil
    end

    values[0] = Genotype.founder_male_x(values[0]) if founder_male
    values[0] = Genotype.male_x(values[0]) if male
    Fly.from_chromosomes(values.map { |value| Genotype.homozygous(value) })
  end

  # Picked from the chromosomes of a previous cross, so old notation is allowed.
  def picked(fields)
    values = fields.map { |field| @params[field].to_s }
    if values.any?(&:blank?)
      @errors << "Not all chromosomes were selected."
      return nil
    end

    Fly.from_chromosomes(values.map { |value| Genotype.homozygous(value) })
  end

  # Only flies the user can reach through their own crosses or stocks.
  def existing_fly(id)
    fly = Fly.find_by(id: id)
    unless fly && @user.can_use_fly?(fly)
      @errors << "That fly was not found."
      return nil
    end
    unless fly.chromosomes.all? { |chromosome| chromosome.split("/").size >= 2 }
      @errors << "That fly has an incomplete genotype. Enter it as a new genotype to cross it."
      return nil
    end
    fly
  end

  def save_parent(fly)
    return fly if fly.persisted?

    fly.cross = @cross
    fly.save!(validate: false)
    fly
  end
end
