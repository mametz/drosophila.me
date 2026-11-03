require "test_helper"

# golden.json was recorded by running the original Rails 4.2 CrossesController.
# This replays the same genotypes through the extracted classes.
class GoldenTest < ActiveSupport::TestCase
  GOLDEN = JSON.parse(File.read(File.expand_path("golden.json", __dir__)))

  GENOTYPES = {
    "wild"            => [ "+/+", "+/+", "+/+", "+/+" ],
    "hemizygous"      => [ "+/-", "+/+", "+/+", "+/+" ],
    "white"           => [ "w", "+/+", "+/+", "+/+" ],
    "white_y"         => [ "w/Y", "+/+", "+/+", "+/+" ],
    "y_white"         => [ "Y/w", "+/+", "+/+", "+/+" ],
    "w1118"           => [ "w^{1118}/w^{1118}", "+/+", "+/+", "+/+" ],
    "x_het"           => [ "w/+", "+/+", "+/+", "+/+" ],
    "second_balancer" => [ "+/+", "Cy/CyO", "+/+", "+/+" ],
    "third_balancer"  => [ "+/+", "+/+", "Sb/TM3", "+/+" ],
    "double_balancer" => [ "w/w", "Sp/CyO", "Sb/TM6B", "+/+" ],
    "gal4_uas"        => [ "w/w", 'P\\{GAL4\\}/+', 'P\\{UAS\\}', "+/+" ],
    "fourth_only"     => [ "+/+", "+/+", "+/+", "ey/+" ],
    "all_four"        => [ "w/+", "Cy/+", "Sb/+", "ey/+" ],
    "three_alleles"   => [ "a/b/c", "+/+", "+/+", "+/+" ],
    "empty"           => [ "", "+/+", "+/+", "+/+" ],
    "y_only"          => [ "Y", "+/+", "+/+", "+/+" ]
  }.freeze

  def dump(value)
    case value
    when Set then { "set" => value.to_a.map { |v| dump(v) } }
    when Array then value.map { |v| dump(v) }
    else value
    end
  end

  def fourth_mutated?(chromosomes)
    chromosomes[3] != "+/+"
  end

  def founder_chromosomes(male, female)
    x = Genotype.homozygous(Genotype.founder_male_x(male[0]))
    [ [ x, *male[1..].map { |c| Genotype.homozygous(c) } ], female.map { |c| Genotype.homozygous(c) } ]
  end

  GENOTYPES.each do |male_name, male|
    GENOTYPES.each do |female_name, female|
      key = "#{male_name} x #{female_name}"

      test "punnett square and allele sets: #{key}" do
        recorded = GOLDEN.fetch("seeded: #{key}")
        punnett = recorded.fetch("punnett")

        # The old app crashed or misaligned the square when only one parent had a
        # mutation on chromosome IV. That was fixed on purpose, so these pairs differ.
        if fourth_mutated?(male) != fourth_mutated?(female)
          square = PunnettSquare.new(male, female)
          assert_equal square.p_mal.size, square.p_femal.size
          mutated, wild = fourth_mutated?(male) ? [ square.p_mal, square.p_femal ] : [ square.p_femal, square.p_mal ]
          assert_equal "ey", mutated.last[0]
          assert_equal [ "+", "+" ], wild.last
        elsif punnett["error"]
          assert_raises(NoMethodError) { PunnettSquare.new(male, female) }
        else
          square = PunnettSquare.new(male, female)
          assert_equal punnett["@male_chrs"], square.male_chrs
          assert_equal punnett["@female_chrs"], square.female_chrs
          assert_equal punnett["@p_mal"], square.p_mal
          assert_equal punnett["@p_femal"], square.p_femal
          assert_equal punnett["@par_male"], square.par_male
          assert_equal punnett["@par_female"], square.par_female
        end

        assert_equal recorded.fetch("show")["@parent_male"], dump(Genotype.new(male).allele_sets)
        assert_equal recorded.fetch("show")["@parent_female"], dump(Genotype.new(female).allele_sets)
      end

      test "founder cross progeny: #{key}" do
        recorded = GOLDEN.fetch("founder: #{key}")

        if recorded.fetch("create")["error"]
          assert_raises(NoMethodError) do
            m, f = founder_chromosomes(male, female)
            CrossCalculator.progeny(m, f)
          end
        else
          flies = recorded.fetch("flies").map { |fly| fly.values_at("chr1", "chr2", "chr3", "chr4") }
          m, f = founder_chromosomes(male, female)
          assert_equal flies[0], m
          assert_equal flies[1], f
          assert_equal flies[2..], CrossCalculator.progeny(m, f)
        end
      end
    end
  end
end
