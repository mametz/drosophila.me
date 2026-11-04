# Lists the F1 chromosomes that carry a recombinant from the mother. Only females
# recombine, so the father's chromosomes stay whole. Map positions aren't known,
# so every combination of the mother's differing alleles counts as possible.
class RecombinantCalculator
  # 6 differing alleles already give 62 recombinants, and the count doubles with each one.
  MAX_DIFFERING_ALLELES = 6
  COMMON_BALANCERS = /\A(FM\d|CyO|SM\d|TM\d|MKRS)/
  FOURTH = 3

  Options = Data.define(:offspring, :reason)

  def initialize(male_chromosomes, female_chromosomes, balancers = [])
    @male_chromosomes = male_chromosomes
    @female_chromosomes = female_chromosomes
    @balancers = balancers
  end

  def options(index)
    return Options.new([], :fourth) if index == FOURTH

    sides = homolog_alleles(@female_chromosomes[index])
    return Options.new([], :identical) if sides.size < 2 || Genotype.y_marker?(@female_chromosomes[index])
    return Options.new([], :balancer) if sides.flatten.any? { |allele| balancer?(allele) }

    shared = sides[0] & sides[1]
    differing = (sides[0] | sides[1]) - shared
    return Options.new([], :too_many) if differing.size > MAX_DIFFERING_ALLELES

    gametes = recombinant_gametes(shared, differing, sides)
    return Options.new([], :identical) if gametes.empty?

    Options.new(father_alleles(index).product(gametes).map(&:to_set).uniq, nil)
  end

  private

  def homolog_alleles(chromosome)
    Genotype.alleles(chromosome).reject(&:empty?).map do |side|
      Genotype.comma_alleles(side).reject { |allele| allele.empty? || allele == "+" }
    end
  end

  def balancer?(allele)
    @balancers.include?(allele) || allele.match?(COMMON_BALANCERS)
  end

  # Sorted so the same recombinant is always written the same way.
  def recombinant_gametes(shared, differing, sides)
    parental = sides.map(&:sort)
    combinations = (0..differing.size).flat_map { |size| differing.combination(size).to_a }
    gametes = combinations.map { |combination| (shared + combination).sort }.uniq - parental
    gametes.sort_by { |alleles| [ alleles.size, alleles ] }.map { |alleles| alleles.empty? ? "+" : alleles.join(",") }
  end

  # Old records can hold a male written as "w/w", which still means one X and a Y.
  def father_alleles(index)
    chromosome = @male_chromosomes[index]
    chromosome = Genotype.male_x(chromosome) if index.zero? && Genotype.valid_male_x?(chromosome)
    Genotype.alleles(chromosome).reject(&:empty?).uniq
  end
end
