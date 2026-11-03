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

  # Males carry one X, so "-" stands in for the Y.
  def self.male_x(chromosome)
    chromosome == "+/+" ? "+/-" : chromosome
  end

  # Founder crosses may also spell the Y out, as in "w/Y".
  def self.founder_male_x(chromosome)
    x = male_x(chromosome)
    alleles = x.split("/")
    x = alleles[1] + "/-" if alleles[0] == "Y"
    x = alleles[0] + "/-" if alleles[1] == "Y"
    x
  end

  # A fly dies when both sister chromosomes carry the same balancer or lethal
  # allele. Alleles on one chromosome are separated by commas.
  def self.lethal_chromosome?(alleles, balancers, lethal)
    alleles = alleles.to_a
    return false if alleles.empty?

    shared = alleles.size == 1 ? alleles[0].split(",") : alleles[0].split(",") & alleles[1].split(",")
    shared.any? { |allele| balancers.include?(allele) || lethal.include?(allele) }
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
end
