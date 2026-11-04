require "test_helper"

class RecombinantCalculatorTest < Minitest::Test
  WILD = "+/+".freeze

  def options(female, male: WILD, index: 1, balancers: [])
    males = [ "+/-", WILD, WILD, WILD ]
    females = [ "+/+", WILD, WILD, WILD ]
    males[index] = male
    females[index] = female
    RecombinantCalculator.new(males, females, balancers).options(index)
  end

  def test_two_alleles_in_trans_give_the_double_mutant_and_wild_type
    assert_equal [ Set["+"], Set["+", "a,b"] ], options("a/b").offspring
  end

  def test_two_alleles_in_cis_can_separate
    assert_equal [ Set["+", "a"], Set["+", "b"] ], options("a,b/+").offspring
  end

  def test_three_alleles_list_every_combination
    gametes = options("a,b/c").offspring.map { |set| (set.to_a - [ "+" ]).first || "+" }
    assert_equal %w[+ a a,c b b,c a,b,c].sort, gametes.sort
  end

  def test_an_allele_on_both_homologs_stays_on_every_gamete
    assert_equal [ Set["+", "c"], Set["+", "a,b,c"] ], options("a,c/b,c").offspring
  end

  def test_spacing_and_order_do_not_change_the_answer
    assert_equal options("a,b/+").offspring, options("b, a/+").offspring
    assert_equal options("a/b").offspring, options("b/a").offspring
  end

  def test_nothing_to_recombine
    [ "+/+", "a/+", "a/a", "a", "a,b/a,b", "a/a,b", "a,b/a" ].each do |female|
      result = options(female)
      assert_empty result.offspring, female
      assert_equal :identical, result.reason, female
    end
  end

  def test_each_father_allele_is_paired_with_each_recombinant
    assert_equal [ Set["Cy", "+"], Set["Cy", "a,b"], Set["+"], Set["+", "a,b"] ].to_set,
                 options("a/b", male: "Cy/+").offspring.to_set
  end

  def test_x_recombinants_go_to_sons_and_daughters
    assert_equal [ Set["w", "+"], Set["w", "a,b"], Set["-", "+"], Set["-", "a,b"] ].to_set,
                 options("a/b", male: "w/-", index: 0).offspring.to_set
  end

  def test_an_old_male_written_as_homozygous_still_has_sons
    assert_includes options("a/b", male: "w/w", index: 0).offspring, Set["-", "a,b"]
  end

  def test_a_female_x_with_a_y_marker_from_old_data_gives_nothing
    assert_empty options("-/w", index: 0).offspring
  end

  def test_the_fourth_chromosome_does_not_cross_over
    result = options("a/b", index: 3)
    assert_empty result.offspring
    assert_equal :fourth, result.reason
  end

  def test_balancers_suppress_crossing_over
    [ "a/CyO", "a/TM6B", "a/TM6B, Tb", "FM7a/a", "a/SM6", "a/MKRS" ].each do |female|
      result = options(female)
      assert_empty result.offspring, female
      assert_equal :balancer, result.reason, female
    end
    assert_equal :balancer, options("a/Bal", balancers: [ "Bal" ]).reason
    refute_equal :balancer, options("a/b", balancers: [ "Bal" ]).reason
  end

  def test_a_long_allele_list_stops_instead_of_listing_thousands
    many = (1..7).map { |n| "a#{n}" }.join(",")
    result = options("#{many}/+")
    assert_empty result.offspring
    assert_equal :too_many, result.reason

    six = (1..6).map { |n| "a#{n}" }.join(",")
    assert_equal 62, options("#{six}/+").offspring.size
  end
end
