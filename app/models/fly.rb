class Fly < ApplicationRecord
  CHROMOSOME = %r{\A[^/]+/[^/]+\z}

  belongs_to :cross, optional: true

  validates :chr1, :chr2, :chr3, :chr4, format: { with: CHROMOSOME }, on: :create

  def self.from_chromosomes(chromosomes, cross: nil)
    new(chr1: chromosomes[0], chr2: chromosomes[1], chr3: chromosomes[2], chr4: chromosomes[3], cross: cross)
  end

  def genotype
    Genotype.of(self)
  end

  def chromosomes
    genotype.chromosomes
  end
end
