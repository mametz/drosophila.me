# Genotypes are drawn by MathJax from the same TeX notation the original site used.
module GenotypeHelper
  def chromosome_tex(alleles)
    alleles = alleles.to_a
    return alleles.join if alleles.size <= 1

    "\\dfrac#{alleles.map { |allele| "{#{allele}}" }.join}"
  end

  def genotype_tex(allele_sets)
    allele_sets.map { |alleles| chromosome_tex(alleles) }.join(" ; ")
  end

  def genotype_math(fly_or_sets)
    sets = fly_or_sets.respond_to?(:genotype) ? fly_or_sets.genotype.allele_sets : fly_or_sets
    "\\[#{genotype_tex(sets)}\\]"
  end

  def chromosome_math(alleles)
    "\\[#{chromosome_tex(alleles)}\\]"
  end

  def chromosome_string(alleles)
    alleles.to_a.join("/")
  end

  def punnett_header(gamete)
    "\\[#{Array(gamete).flatten.join(" ; ")}\\]"
  end

  # Gametes hold one allele per chromosome. A chromosome missing on one side is wild type.
  def punnett_cell(male, female)
    male = Array(male).flatten
    female = Array(female).flatten
    pairs = (0...[ male.size, female.size ].max).map do |index|
      "\\frac{#{male[index] || "+"}}{#{female[index] || "+"}}"
    end
    "\\[#{pairs.join(" ; ")}\\]"
  end
end
