# Readable examples of the genetics rules, including today's known quirks:
#
#   ruby test/characterization/genetics_test.rb
require 'minitest/autorun'
root = File.expand_path('../..', __dir__)
%w(genotype cross_calculator punnett_square).each { |f| require File.join(root, 'app/models', f) }

class GenotypeTest < Minitest::Test
  def test_single_allele_means_homozygous
    assert_equal 'w/w', Genotype.homozygous('w')
    assert_equal 'w/+', Genotype.homozygous('w/+')
  end

  def test_wild_type_male_x_is_hemizygous
    assert_equal '+/-', Genotype.male_x('+/+')
    assert_equal 'w/w', Genotype.male_x('w/w')
  end

  def test_founder_male_x_replaces_a_written_y
    assert_equal 'w/-', Genotype.founder_male_x('w/Y')
    assert_equal 'w/-', Genotype.founder_male_x('Y/w')
    assert_equal '+/-', Genotype.founder_male_x('+/+')
  end

  def test_allele_sets_collapse_duplicates
    sets = Genotype.new(['w/w', 'Cy/+', '+/+', '+/+']).allele_sets
    assert_equal [Set['w'], Set['Cy', '+'], Set['+'], Set['+']], sets
  end
end

class CrossCalculatorTest < Minitest::Test
  WILD = ['+/+', '+/+', '+/+', '+/+'].freeze

  def test_wild_type_cross_has_one_offspring
    assert_equal [WILD], CrossCalculator.progeny(WILD, WILD)
  end

  def test_x_linked_cross_gives_daughters_and_sons
    male = ['+/-', '+/+', '+/+', '+/+']
    female = ['w/w', '+/+', '+/+', '+/+']
    assert_equal [['+/w', '+/+', '+/+', '+/+'], ['-/w', '+/+', '+/+', '+/+']],
                 CrossCalculator.progeny(male, female)
  end

  def test_reciprocal_alleles_count_once
    male = ['+/+', 'Cy/+', '+/+', '+/+']
    female = ['+/+', 'Cy/+', '+/+', '+/+']
    assert_equal ['Cy/Cy', 'Cy/+', '+/+'], CrossCalculator.progeny(male, female).map { |o| o[1] }
  end

  def test_lethal_combinations_are_not_removed
    male = ['+/+', 'CyO/+', '+/+', '+/+']
    assert_includes CrossCalculator.progeny(male, male).map { |o| o[1] }, 'CyO/CyO'
  end
end

class PunnettSquareTest < Minitest::Test
  WILD = ['+/+', '+/+', '+/+', '+/+'].freeze

  def test_wild_type_cross_has_a_single_cell
    square = PunnettSquare.new(WILD, WILD)
    assert_equal [['+']], square.male_chrs
    assert_equal [['+']], square.female_chrs
  end

  def test_hemizygous_male_with_wild_female_counts_as_wild
    assert_equal [['+']], PunnettSquare.new(['+/-', '+/+', '+/+', '+/+'], WILD).male_chrs
  end

  def test_chromosome_mutated_in_one_parent_is_padded_with_wild_type
    square = PunnettSquare.new(['+/+', 'Cy/+', '+/+', '+/+'], WILD)
    assert_equal ['Cy', '+'], square.male_chrs
    assert_equal ['+'], square.female_chrs
  end

  def test_several_chromosomes_are_combined
    square = PunnettSquare.new(['+/+', 'Cy/+', 'Sb/+', '+/+'], WILD)
    assert_equal [['Cy', 'Sb'], ['Cy', '+'], ['+', 'Sb'], ['+', '+']], square.male_chrs
  end

  # Known bugs, pinned so they change on purpose rather than by accident.
  def test_quirk_fourth_chromosome_mutation_only_in_male_crashes
    assert_raises(NoMethodError) { PunnettSquare.new(['+/+', '+/+', '+/+', 'ey/+'], WILD) }
  end

  def test_quirk_fourth_chromosome_mutation_only_in_female_is_dropped
    square = PunnettSquare.new(WILD, ['+/+', '+/+', '+/+', 'ey/+'])
    assert_equal [['+']], square.male_chrs
    assert_equal [['+']], square.female_chrs
  end
end
