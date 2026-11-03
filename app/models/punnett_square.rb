# The row and column headers of a Punnett square. Chromosomes that are wild type
# in both parents are left out.
class PunnettSquare
  attr_reader :par_male, :par_female, :p_mal, :p_femal, :male_chrs, :female_chrs

  def initialize(male_chromosomes, female_chromosomes)
    @par_male = male_chromosomes.map { |chromosome| chromosome.split("/") }
    @par_female = female_chromosomes.map { |chromosome| chromosome.split("/") }

    treat_hemizygous_male_as_wild_type

    @p_mal = @par_male.map { |chromosome| chromosome unless wild_type?(chromosome) }
    @p_femal = @par_female.map { |chromosome| chromosome unless wild_type?(chromosome) }

    # Stops at chromosome III, so a mutation only on IV in one parent is not
    # padded. Pinned by the characterization tests as existing behaviour.
    3.times do |i|
      @p_mal[i] = [ "+", "+" ] if @p_mal[i].nil? && !@p_femal[i].nil?
      @p_femal[i] = [ "+", "+" ] if !@p_mal[i].nil? && @p_femal[i].nil?
    end

    @p_mal = @p_mal.compact
    @p_femal = @p_femal.compact

    @male_chrs = combinations(@p_mal)
    @female_chrs = combinations(@p_femal)

    if @p_mal.empty?
      @male_chrs = [ [ "+" ] ]
      @female_chrs = [ [ "+" ] ]
    end

    @male_chrs = @male_chrs.uniq
    @female_chrs = @female_chrs.uniq
  end

  private

  def treat_hemizygous_male_as_wild_type
    x_m = @par_male[0]
    x_f = @par_female[0]
    return unless x_f[0] == "+" && x_f[1] == "+"

    x_m[1] = "+" if x_m[0] == "+" && x_m[1] == "-"
    x_m[0] = "+" if x_m[1] == "+" && x_m[0] == "-"
  end

  def wild_type?(chromosome)
    chromosome[0] == "+" && chromosome[1] == "+"
  end

  def combinations(chromosomes)
    chromosomes.drop(1).reduce(chromosomes[0]) { |combined, chromosome| combined.product(chromosome) }
  end
end
