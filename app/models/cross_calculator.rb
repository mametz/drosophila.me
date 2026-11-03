require 'set'

# Works out which offspring genotypes a cross can produce.
class CrossCalculator
  # Takes each parent's four chromosome strings and returns one array of four
  # chromosome strings per distinct offspring. Allele order follows the male,
  # so "a/b" and "b/a" count as the same chromosome.
  def self.progeny(male_chromosomes, female_chromosomes)
    pairings = male_chromosomes.zip(female_chromosomes).map do |male, female|
      pairings_for(male.split('/'), female.split('/'))
    end

    pairings[0].product(*pairings[1..-1]).uniq.map do |offspring|
      offspring.map { |pairing| chromosome_string(pairing) }
    end
  end

  def self.pairings_for(m, f)
    [Set[m[0], f[0]], Set[m[0], f[1]], Set[m[1], f[0]], Set[m[1], f[1]]]
  end
  private_class_method :pairings_for

  def self.chromosome_string(pairing)
    if pairing.size == 1
      pairing.to_a[0] + "/" + pairing.to_a[0]
    else
      pairing.to_a.join('/')
    end
  end
  private_class_method :chromosome_string
end
