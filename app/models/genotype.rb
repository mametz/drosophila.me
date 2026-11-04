require "set"

# The four chromosomes of one fly, each written as "allele/allele".
# Plain Ruby so it can be tested without booting Rails.
class Genotype
  attr_reader :chromosomes

  def self.of(fly)
    new([ fly.chr1, fly.chr2, fly.chr3, fly.chr4 ])
  end

  def self.homozygous(chromosome)
    if !chromosome.include? "/"
      chromosome + "/" + chromosome
    else
      chromosome
    end
  end

  # What stands in for the Y on the X chromosome field. "-" is the stored form.
  Y_MARKERS = %w[- Y].freeze

  def self.alleles(chromosome)
    chromosome.split("/").map(&:strip)
  end

  def self.x_alleles(chromosome)
    alleles(chromosome).reject { |allele| allele.empty? || Y_MARKERS.include?(allele) }
  end

  def self.y_marker?(chromosome)
    alleles(chromosome).intersect?(Y_MARKERS)
  end

  # Males carry one X, so "w", "w/w", "w/Y" and "w/-" all mean the same male.
  # "w/+" would be two different X chromosomes, which a male can't have.
  def self.valid_male_x?(chromosome)
    x_alleles(chromosome).uniq.one? && alleles(chromosome).size <= 2
  end

  def self.valid_female_x?(chromosome)
    !y_marker?(chromosome) && x_alleles(chromosome).any?
  end

  def self.male_x(chromosome)
    return chromosome if alleles(chromosome).include?("-") && !alleles(chromosome).include?("Y")

    "#{x_alleles(chromosome).first}/-"
  end

  # The X chromosomes a son of this mother can have.
  def self.sons_x(mother_x)
    x_alleles(mother_x).uniq.map { |allele| [ allele, "-" ].to_set }
  end

  # A fly dies when both sister chromosomes carry the same balancer or lethal
  # allele, or when it has no X. A son has nothing to cover a lethal allele on
  # his only X, but balancers stay out of that rule because FM7 males are viable.
  # Alleles on one chromosome are separated by commas.
  def self.lethal_chromosome?(alleles, balancers, lethal)
    alleles = alleles.to_a.map(&:strip)
    return false if alleles.empty?
    return true if alleles.all? { |allele| Y_MARKERS.include?(allele) }

    if alleles.size == 2 && alleles.intersect?(Y_MARKERS)
      x_allele = (alleles - Y_MARKERS).first
      return comma_alleles(x_allele).any? { |allele| lethal.include?(allele) }
    end

    shared = alleles.size == 1 ? comma_alleles(alleles[0]) : comma_alleles(alleles[0]) & comma_alleles(alleles[1])
    shared.any? { |allele| balancers.include?(allele) || lethal.include?(allele) }
  end

  def self.comma_alleles(allele)
    allele.split(",").map(&:strip)
  end

  def initialize(chromosomes)
    @chromosomes = chromosomes
  end

  def allele_sets
    chromosomes.map { |chromosome| chromosome.split("/").to_set }
  end

  def lethal?(balancers, lethal)
    allele_sets.any? { |alleles| self.class.lethal_chromosome?(alleles, balancers, lethal) }
  end

  def can_be_male?
    self.class.valid_male_x?(chromosomes[0])
  end

  def can_be_female?
    self.class.valid_female_x?(chromosomes[0])
  end
end
