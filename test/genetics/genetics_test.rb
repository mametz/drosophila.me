# Readable examples of the genetics rules.
require "test_helper"

class GenotypeTest < Minitest::Test
  def test_single_allele_means_homozygous
    assert_equal "w/w", Genotype.homozygous("w")
    assert_equal "w/+", Genotype.homozygous("w/+")
  end

  def test_a_male_has_one_x
    { "+/+" => "+/-", "w/w" => "w/-", "w" => "w/-", "w/Y" => "w/-", "Y/w" => "w/-",
      "w/-" => "w/-", "-/w" => "-/w", "/w" => "w/-" }.each do |typed, stored|
      assert Genotype.valid_male_x?(typed), typed
      assert_equal stored, Genotype.male_x(typed), typed
    end
  end

  def test_a_male_cannot_have_two_different_x
    [ "w/+", "a/b/c", "Y", "Y/Y", "-/-", "-/Y", "" ].each { |x| refute Genotype.valid_male_x?(x), x }
  end

  def test_a_female_has_no_y
    %w[w w/w w/+ /w].each { |x| assert Genotype.valid_female_x?(x), x }
    %w[-/w w/- w/Y Y -].each { |x| refute Genotype.valid_female_x?(x), x }
  end

  def test_sons_take_one_x_from_their_mother
    assert_equal [ Set["w", "-"], Set["+", "-"] ], Genotype.sons_x("w/+")
    assert_equal [ Set["w", "-"] ], Genotype.sons_x("w/w")
  end

  def test_homozygous_lethal_and_balancer_die
    assert Genotype.lethal_chromosome?(Set["jig"], [], [ "jig" ])
    assert Genotype.lethal_chromosome?(Set["CyO"], [ "CyO" ], [])
    refute Genotype.lethal_chromosome?(Set["jig", "+"], [], [ "jig" ])
  end

  def test_alleles_on_one_chromosome_match_with_or_without_spaces
    assert Genotype.lethal_chromosome?(Set["TM6B, Tb"], [], [ "Tb" ])
    assert Genotype.lethal_chromosome?(Set["TM6B, Tb", "Sb,Tb"], [], [ "Tb" ])
    refute Genotype.lethal_chromosome?(Set["CyO"], [ "Cyo" ], []), "symbols stay case-sensitive"
  end

  def test_no_x_at_all_dies
    assert Genotype.lethal_chromosome?(Set["-"], [], [])
    assert Genotype.lethal_chromosome?(Set["-", "Y"], [], [])
  end

  def test_a_son_dies_of_a_lethal_on_his_x_but_not_of_a_balancer
    assert Genotype.lethal_chromosome?(Set["l", "-"], [], [ "l" ])
    assert Genotype.lethal_chromosome?(Set["-", "a,l"], [], [ "l" ])
    refute Genotype.lethal_chromosome?(Set["FM7", "-"], [ "FM7" ], [])
    refute Genotype.lethal_chromosome?(Set["w", "-"], [], [ "l" ])
  end

  def test_which_role_a_fly_can_fill
    son = Genotype.new([ "-/w", "+/+", "+/+", "+/+" ])
    daughter = Genotype.new([ "w/+", "+/+", "+/+", "+/+" ])
    written_as_homozygous = Genotype.new([ "w/w", "+/+", "+/+", "+/+" ])
    assert son.can_be_male?
    refute son.can_be_female?
    refute daughter.can_be_male?
    assert daughter.can_be_female?
    assert written_as_homozygous.can_be_male?
    assert written_as_homozygous.can_be_female?
  end

  def test_allele_sets_collapse_duplicates
    sets = Genotype.new([ "w/w", "Cy/+", "+/+", "+/+" ]).allele_sets
    assert_equal [ Set["w"], Set["Cy", "+"], Set["+"], Set["+"] ], sets
  end
end

class CrossCalculatorTest < Minitest::Test
  WILD = [ "+/+", "+/+", "+/+", "+/+" ].freeze

  def test_wild_type_cross_has_one_offspring
    assert_equal [ WILD ], CrossCalculator.progeny(WILD, WILD)
  end

  def test_x_linked_cross_gives_daughters_and_sons
    male = [ "+/-", "+/+", "+/+", "+/+" ]
    female = [ "w/w", "+/+", "+/+", "+/+" ]
    assert_equal [ [ "+/w", "+/+", "+/+", "+/+" ], [ "-/w", "+/+", "+/+", "+/+" ] ],
                 CrossCalculator.progeny(male, female)
  end

  def test_reciprocal_alleles_count_once
    male = [ "+/+", "Cy/+", "+/+", "+/+" ]
    female = [ "+/+", "Cy/+", "+/+", "+/+" ]
    assert_equal [ "Cy/Cy", "Cy/+", "+/+" ], CrossCalculator.progeny(male, female).map { |o| o[1] }
  end

  def test_lethal_combinations_are_not_removed
    male = [ "+/+", "CyO/+", "+/+", "+/+" ]
    assert_includes CrossCalculator.progeny(male, male).map { |o| o[1] }, "CyO/CyO"
  end
end

class PunnettSquareTest < Minitest::Test
  WILD = [ "+/+", "+/+", "+/+", "+/+" ].freeze

  def test_wild_type_cross_has_a_single_cell
    square = PunnettSquare.new(WILD, WILD)
    assert_equal [ [ "+" ] ], square.male_chrs
    assert_equal [ [ "+" ] ], square.female_chrs
  end

  def test_hemizygous_male_with_wild_female_counts_as_wild
    assert_equal [ [ "+" ] ], PunnettSquare.new([ "+/-", "+/+", "+/+", "+/+" ], WILD).male_chrs
  end

  def test_chromosome_mutated_in_one_parent_is_padded_with_wild_type
    square = PunnettSquare.new([ "+/+", "Cy/+", "+/+", "+/+" ], WILD)
    assert_equal [ "Cy", "+" ], square.male_chrs
    assert_equal [ "+" ], square.female_chrs
  end

  def test_several_chromosomes_are_combined
    square = PunnettSquare.new([ "+/+", "Cy/+", "Sb/+", "+/+" ], WILD)
    assert_equal [ [ "Cy", "Sb" ], [ "Cy", "+" ], [ "+", "Sb" ], [ "+", "+" ] ], square.male_chrs
  end

  def test_fourth_chromosome_mutated_only_in_male_is_padded
    square = PunnettSquare.new([ "+/+", "+/+", "+/+", "ey/+" ], WILD)
    assert_equal [ "ey", "+" ], square.male_chrs
    assert_equal [ "+" ], square.female_chrs
  end

  def test_fourth_chromosome_mutated_only_in_female_is_padded
    square = PunnettSquare.new(WILD, [ "+/+", "+/+", "+/+", "ey/+" ])
    assert_equal [ "+" ], square.male_chrs
    assert_equal [ "ey", "+" ], square.female_chrs
  end

  def test_fourth_chromosome_is_combined_with_the_others
    square = PunnettSquare.new([ "+/+", "Cy/+", "+/+", "+/+" ], [ "+/+", "+/+", "+/+", "ey/+" ])
    assert_equal [ [ "Cy", "+" ], [ "+", "+" ] ], square.male_chrs
    assert_equal [ [ "+", "ey" ], [ "+", "+" ] ], square.female_chrs
  end
end
