require "test_helper"

class CrossesTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @other = users(:two)
  end

  def date
    { "crossdate(1i)" => "2015", "crossdate(2i)" => "11", "crossdate(3i)" => "1" }
  end

  def founder(male: %w[w/Y Cy/+ +/+ +/+], female: %w[w/w +/+ Sb/+ +/+], **extra)
    { cross: date.merge(description: "first", balancers: "CyO;TM3", lethal: "l(2)/x",
                        m_X: male[0], m_II: male[1], m_III: male[2], m_IV: male[3],
                        f_X: female[0], f_II: female[1], f_III: female[2], f_IV: female[3]).merge(extra) }
  end

  def create_founder(**options)
    post crosses_path, params: founder(**options)
    assert_response :redirect
    Cross.order(:id).last
  end

  def follow_on(parent, **fields)
    post crosses_path, params: { cross: date.merge(description: "next", balancers: "", lethal: "", parent: parent).merge(fields) }
  end

  test "creating a founder cross stores normalized parents and progeny" do
    sign_in_as @owner
    cross = create_founder
    assert_redirected_to short_path(cross)
    assert_equal %w[w/- Cy/+ +/+ +/+], cross.male_fly.chromosomes
    assert_equal %w[w/w +/+ Sb/+ +/+], cross.female_fly.chromosomes
    expected = CrossCalculator.progeny(cross.male_fly.chromosomes, cross.female_fly.chromosomes)
    assert_equal expected, cross.progeny.map(&:chromosomes)
    assert_match(/\A\h{32}\z/, cross.slug)
  end

  test "bad genotypes are rejected without saving anything" do
    sign_in_as @owner
    [ [ "Y", "+/+", "+/+", "+/+" ], [ "", "+/+", "+/+", "+/+" ], [ "a/b/c", "+/+", "+/+", "+/+" ] ].each do |male|
      assert_no_difference([ "Cross.count", "Fly.count" ]) do
        post crosses_path, params: founder(male: male)
      end
      assert_response :unprocessable_entity
    end
  end

  test "follow-on crosses from flies, typed genotypes and picked chromosomes" do
    sign_in_as @owner
    source = create_founder
    male = source.male_fly_id.to_s
    female = source.female_fly_id.to_s
    typed = { X: "w/w", II: "Cy", III: "+/+", IV: "+/+" }
    picked_m = { m_X: "w/-", m_II: "Cy", m_III: "+/+", m_IV: "+/+" }
    picked_f = { f_X: "w", f_II: "+/+", f_III: "Sb/+", f_IV: "+/+" }

    { "new male" => [ { male_id: "new", female_id: female }.merge(typed), [ "w/-", "Cy/Cy", "+/+", "+/+" ] ],
      "new wild male" => [ { male_id: "new", female_id: female }.merge(typed).merge(X: "+/+"), [ "+/-", "Cy/Cy", "+/+", "+/+" ] ],
      "existing flies" => [ { male_id: male, female_id: female }, source.male_fly.chromosomes ],
      "both picked" => [ { male_id: "male_chr_s", female_id: "female_chr_s" }.merge(picked_m).merge(picked_f), [ "w/-", "Cy/Cy", "+/+", "+/+" ] ],
      # These two crashed the old app
      "male picked" => [ { male_id: "male_chr_s", female_id: female }.merge(picked_m), [ "w/-", "Cy/Cy", "+/+", "+/+" ] ],
      "female picked" => [ { male_id: male, female_id: "female_chr_s" }.merge(picked_f), source.male_fly.chromosomes ] }.each do |name, (fields, expected_male)|
      assert_difference("Cross.count", 1, name) { follow_on(source.id, **fields) }
      cross = Cross.order(:id).last
      assert_equal source, cross.parent, name
      assert_equal expected_male, cross.male_fly.chromosomes, name
      assert cross.progeny.any?, name
      get short_path(cross)
      assert_response :success, name
    end
  end

  test "incomplete follow-on crosses go back with a message" do
    sign_in_as @owner
    source = create_founder
    male = source.male_fly_id.to_s
    female = source.female_fly_id.to_s

    { "Not all parents were selected." => [ { female_id: female }, { male_id: male } ],
      "Not all chromosomes were selected." => [ { male_id: "male_chr_s", female_id: "female_chr_s", m_X: "w/-" } ] }.each do |message, attempts|
      attempts.each do |fields|
        assert_no_difference("Cross.count") { follow_on(source.id, **fields) }
        assert_redirected_to short_path(source)
        assert_includes flash[:alert], message
      end
    end
  end

  test "crossing stocks leaves the parent empty and returns to stocks on error" do
    sign_in_as @owner
    source = create_founder
    stock = @owner.stocks.create!(fly: source.male_fly, number: 1)
    assert_difference("Cross.count", 1) { follow_on("stock", male_id: stock.fly_id.to_s, female_id: source.female_fly_id.to_s) }
    assert_nil Cross.order(:id).last.parent_id

    assert_no_difference("Cross.count") { follow_on("stock", female_id: source.female_fly_id.to_s) }
    assert_redirected_to stocks_path
  end

  test "someone else's flies and crosses cannot be used as parents" do
    sign_in_as @owner
    source = create_founder
    sign_out
    sign_in_as @other
    mine = create_founder

    assert_no_difference("Cross.count") { follow_on(mine.id, male_id: source.male_fly_id.to_s, female_id: mine.female_fly_id.to_s) }
    assert_includes flash[:alert], "fly was not found"
    assert_no_difference("Cross.count") { follow_on(source.id, male_id: mine.male_fly_id.to_s, female_id: mine.female_fly_id.to_s) }
    assert_includes flash[:alert], "cross was not found"
  end

  test "shared crosses are public on every short link, without logging in" do
    sign_in_as @owner
    cross = create_founder
    sign_out
    [ "/#{cross.slug}", "/#{cross.slug}/chr", "/#{cross.slug}/pnt", "/#{cross.slug}/qr",
      "/crosses/#{cross.slug}", "/crosses/#{cross.slug}/qr" ].each do |path|
      get path
      assert_response :success, path
    end
    get "/#{cross.slug}/history"
    assert_response :success
  end

  test "private crosses are hidden from everyone but the owner" do
    sign_in_as @owner
    cross = create_founder
    patch cross_path(cross), params: { cross: { shared: false } }
    assert_redirected_to short_path(cross)
    get short_path(cross)
    assert_response :success
    sign_out
    get short_path(cross)
    assert_response :not_found
    sign_in_as @other
    get short_path(cross)
    assert_response :not_found
    assert_no_difference("Cross.count") { post copy_cross_path(cross) }
    assert_response :not_found
  end

  test "pages draw the genotypes in the notation MathJax expects" do
    sign_in_as @owner
    cross = create_founder
    get short_path(cross)
    assert_select ".parent", 2
    assert_includes response.body, "\\dfrac{w}{-}"
    assert_includes response.body, "mathjax@3.2.2"
  end

  test "a male typed with two identical X chromosomes has sons" do
    sign_in_as @owner
    %w[w/w w w/Y Y/w w/-].each do |typed|
      cross = create_founder(male: [ typed, "+/+", "+/+", "+/+" ], female: %w[+/+ +/+ +/+ +/+])
      assert_equal "w/-", cross.male_fly.chr1, typed
      assert_equal %w[w/+ -/+], cross.progeny.map(&:chr1), typed
    end
  end

  test "a male with two different X chromosomes is refused with a reason" do
    sign_in_as @owner
    assert_no_difference([ "Cross.count", "Fly.count" ]) do
      post crosses_path, params: founder(male: %w[w/+ +/+ +/+ +/+])
    end
    assert_response :unprocessable_entity
    assert_includes response.body, "A male has one X chromosome"
  end

  test "a female carrying a Y is refused with a reason" do
    sign_in_as @owner
    [ "w/Y", "w/-" ].each do |x|
      assert_no_difference("Cross.count") { post crosses_path, params: founder(female: [ x, "+/+", "+/+", "+/+" ]) }
      assert_includes response.body, "A female has two X chromosomes"
    end
  end

  test "follow-on crosses hold to the same rules in every path" do
    sign_in_as @owner
    source = create_founder
    son = source.progeny.find { |fly| fly.chr1.include?("-") }
    daughter = source.progeny.find { |fly| !fly.chr1.include?("-") }
    wild = { X: "+/+", II: "+/+", III: "+/+", IV: "+/+" }

    { "son as female" => { male_id: source.male_fly_id.to_s, female_id: son.id.to_s },
      "daughter as male" => { male_id: Fly.create!(chr1: "w/+", chr2: "+/+", chr3: "+/+", chr4: "+/+", cross: source).id.to_s, female_id: daughter.id.to_s },
      "typed Y on a new female" => { male_id: son.id.to_s, female_id: "new" }.merge(wild).merge(X: "w/Y"),
      "typed two X on a new male" => { male_id: "new", female_id: daughter.id.to_s }.merge(wild).merge(X: "w/+"),
      "picked Y for the female" => { male_id: son.id.to_s, female_id: "female_chr_s", f_X: "-/w", f_II: "+", f_III: "+", f_IV: "+" },
      "picked two X for the male" => { male_id: "male_chr_s", female_id: daughter.id.to_s, m_X: "w/+", m_II: "+", m_III: "+", m_IV: "+" } }.each do |name, fields|
      assert_no_difference("Cross.count", name) { follow_on(source.id, **fields) }
      assert_redirected_to short_path(source), name
    end

    assert_difference("Cross.count", 1) { follow_on(source.id, male_id: "new", female_id: daughter.id.to_s, **wild.merge(X: "w/Y")) }
    assert_equal "w/-", Cross.order(:id).last.male_fly.chr1
  end

  test "an old fly written as w/w can father a cross through a corrected copy" do
    sign_in_as @owner
    cross = create_founder
    old = Fly.create!(chr1: "w/w", chr2: "+/+", chr3: "+/+", chr4: "+/+", cross: cross)
    daughter = cross.progeny.find { |fly| !fly.chr1.include?("-") }
    follow_on(cross.id, male_id: old.id.to_s, female_id: daughter.id.to_s)
    child = Cross.order(:id).last
    assert_equal "w/-", child.male_fly.chr1
    assert_not_equal old.id, child.male_fly_id
    assert_equal "w/w", old.reload.chr1
    assert child.progeny.any? { |fly| fly.chr1.include?("-") }, "has sons"
  end

  test "the fly view offers each fly only in the role it can fill" do
    sign_in_as @owner
    cross = create_founder(male: %w[w/- +/+ +/+ +/+], female: %w[+/+ +/+ +/+ +/+])
    son = cross.progeny.find { |fly| fly.chr1.include?("-") }
    daughter = cross.progeny.find { |fly| !fly.chr1.include?("-") }
    get short_path(cross)
    assert_select "input[name='cross[male_id]'][value='#{son.id}']"
    assert_select "input[name='cross[female_id]'][value='#{son.id}']", 0
    assert_select "input[name='cross[female_id]'][value='#{daughter.id}']"
    assert_select "input[name='cross[male_id]'][value='#{daughter.id}']", 0
  end

  test "a homozygous daughter is only offered as a female when the cross has sons" do
    sign_in_as @owner
    cross = create_founder(male: %w[w/- +/+ +/+ +/+], female: %w[w/w +/+ +/+ +/+])
    daughter = cross.progeny.find { |fly| fly.chr1 == "w/w" }
    get short_path(cross)
    assert_select "input[name='cross[female_id]'][value='#{daughter.id}']"
    assert_select "input[name='cross[male_id]'][value='#{daughter.id}']", 0
  end

  test "imported Y/Y flies and sons with a lethal X are hidden, and the data is kept" do
    sign_in_as @owner
    cross = create_founder(male: %w[+/- +/+ +/+ +/+], female: %w[l/+ +/+ +/+ +/+])
    cross.update!(lethal: "l")
    no_x = Fly.new(chr1: "-/-", chr2: "+/+", chr3: "+/+", chr4: "+/+", cross: cross)
    no_x.save!(validate: false)
    visible = cross.viable_progeny.map(&:chr1)
    assert_not_includes visible, "-/-"
    assert_not_includes visible, "-/l"
    assert_includes visible, "-/+"
    assert_includes visible, "+/l"
    assert Fly.exists?(no_x.id)
  end

  test "chromosome view works out sons for an old cross that stored none" do
    sign_in_as @owner
    cross = @owner.crosses.create!(crossdate: Date.current)
    male = Fly.create!(chr1: "w/w", chr2: "+/+", chr3: "+/+", chr4: "+/+", cross: cross)
    female = Fly.create!(chr1: "y/y", chr2: "+/+", chr3: "+/+", chr4: "+/+", cross: cross)
    Fly.create!(chr1: "w/y", chr2: "+/+", chr3: "+/+", chr4: "+/+", cross: cross)
    cross.update!(male_fly: male, female_fly: female)
    get chromosome_path(cross)
    assert_response :success
    assert_select "input[name='cross[m_X]'][value='y/-']"
    assert_select "input[name='cross[f_X]'][value='w/y']"
    assert_select "input[name='cross[m_X]'][value='w/y']", 0
  end

  test "lethal homozygotes are hidden from the fly view" do
    sign_in_as @owner
    cross = create_founder(male: %w[+/- CyO/+ +/+ +/+], female: %w[+/+ CyO/+ +/+ +/+])
    assert cross.progeny.any? { |fly| fly.chr2 == "CyO/CyO" }
    assert_not cross.viable_progeny.any? { |fly| fly.chr2 == "CyO/CyO" }
    get short_path(cross)
    assert_not_includes response.body, "{CyO}{CyO}"
    assert_includes response.body, "\\dfrac{CyO}{+}"
  end

  test "Punnett cells show every chromosome" do
    sign_in_as @owner
    cross = create_founder(male: %w[+/- Cy/+ Sb/+ +/+], female: %w[+/+ +/+ +/+ +/+])
    get punnett_path(cross)
    assert_response :success
    assert_includes response.body, "\\frac{Cy}{+} ; \\frac{Sb}{+}"
  end

  test "Punnett page shows a chromosome IV mutation carried by only one parent" do
    sign_in_as @owner
    [ { male: %w[+/- +/+ +/+ ey/+], female: %w[+/+ +/+ +/+ +/+] },
      { male: %w[+/- +/+ +/+ +/+], female: %w[+/+ +/+ +/+ ey/+] } ].each do |parents|
      cross = create_founder(**parents)
      get punnett_path(cross)
      assert_response :success
      assert_includes response.body, "\\frac{ey}{+}" if parents[:male][3] != "+/+"
      assert_includes response.body, "\\frac{+}{ey}" if parents[:female][3] != "+/+"
    end
  end

  test "chromosome view offers the chromosomes of viable progeny" do
    sign_in_as @owner
    cross = create_founder(male: %w[w/- Cy/+ +/+ +/+], female: %w[w/w +/+ +/+ +/+])
    get chromosome_path(cross)
    assert_response :success
    assert_select "input[type=radio][name='cross[m_X]'][value='-/w']"
    assert_select "input[type=radio][name='cross[f_X]'][value='w']"
    assert_select "input[type=radio][name='cross[m_II]'][value='Cy/+']"
  end

  test "history runs oldest first and survives a loop in old data" do
    sign_in_as @owner
    grandparent = create_founder
    follow_on(grandparent.id, male_id: grandparent.male_fly_id.to_s, female_id: grandparent.female_fly_id.to_s)
    child = Cross.order(:id).last
    assert_equal [ grandparent, child ], child.lineage
    get history_path(child)
    assert_response :success
    assert_select "h2", "F2"

    grandparent.update_column(:parent_id, child.id)
    assert_equal [ grandparent, child ].to_set, child.lineage.to_set
    get history_path(child)
    assert_response :success
  end

  test "history leaves out private ancestors of other people" do
    sign_in_as @owner
    ancestor = create_founder
    ancestor.update!(shared: false)
    sign_out
    sign_in_as @other
    mine = create_founder
    mine.update!(parent: ancestor)
    get history_path(mine)
    assert_response :success
    assert_select "h2", text: "F2", count: 0
  end

  test "copying needs login, uses POST and duplicates the flies" do
    sign_in_as @owner
    cross = create_founder
    sign_out
    assert_no_difference("Cross.count") { post copy_cross_path(cross) }
    assert_redirected_to new_session_path

    sign_in_as @other
    get "/copy/#{cross.slug}"
    assert_response :not_found
    assert_difference("Cross.count", 1) { post copy_cross_path(cross) }
    copy = Cross.order(:id).last
    assert_equal @other, copy.user
    assert_equal cross.progeny.map(&:chromosomes), copy.progeny.map(&:chromosomes)
    assert_not_equal cross.male_fly_id, copy.male_fly_id
  end

  test "only the owner can change or delete a cross" do
    sign_in_as @owner
    cross = create_founder
    sign_out
    sign_in_as @other
    delete cross_path(cross)
    assert_response :not_found
    patch cross_path(cross), params: { cross: { shared: false } }
    assert_response :not_found
    assert cross.reload.shared?
  end

  test "deleting a cross keeps its children and any stocks made from its flies" do
    sign_in_as @owner
    parent = create_founder
    follow_on(parent.id, male_id: parent.male_fly_id.to_s, female_id: parent.female_fly_id.to_s)
    child = Cross.order(:id).last
    stock = @owner.stocks.create!(fly: parent.progeny.first, number: 3)

    delete cross_path(parent)
    assert_redirected_to crosses_path
    assert_nil child.reload.parent_id
    assert child.male_fly
    assert stock.reload.fly
    get short_path(child)
    assert_response :success
  end

  test "index only lists your own crosses and needs login" do
    get crosses_path
    assert_redirected_to new_session_path
    sign_in_as @owner
    mine = create_founder
    sign_out
    sign_in_as @other
    get crosses_path
    assert_response :success
    assert_not_includes response.body, mine.slug
  end

  test "flies with old notation from the previous app can be viewed, crossed and copied" do
    cross = @owner.crosses.create!(crossdate: Date.current)
    male = Fly.new(chr1: "/w", chr2: "a/b/c", chr3: "+/+", chr4: "+/+", cross: cross)
    female = Fly.new(chr1: "w/w", chr2: "+/+", chr3: "", chr4: "+/+", cross: cross)
    progeny = Fly.new(chr1: "/w", chr2: "a/+", chr3: "+/+", chr4: "+/+", cross: cross)
    [ male, female, progeny ].each { |fly| fly.save!(validate: false) }
    cross.update!(male_fly: male, female_fly: female)

    sign_in_as @owner
    [ short_path(cross), chromosome_path(cross), punnett_path(cross), history_path(cross), qr_path(cross) ].each do |path|
      get path
      assert_response :success, path
    end

    assert_difference("Cross.count", 1) { follow_on(cross.id, male_id: male.id.to_s, female_id: progeny.id.to_s) }
    assert_equal "w/-", Cross.order(:id).last.male_fly.chr1
    assert_equal "/w", male.reload.chr1, "the old record stays as it was"

    assert_difference("Cross.count", 1) do
      follow_on(cross.id, male_id: "male_chr_s", female_id: progeny.id.to_s, m_X: "/w", m_II: "a/+", m_III: "+", m_IV: "+")
    end

    sign_out
    sign_in_as @other
    assert_difference("Cross.count", 1) { post copy_cross_path(cross) }
  end

  test "a fly missing an allele gets a message instead of a crash" do
    cross = @owner.crosses.create!(crossdate: Date.current)
    fly = Fly.new(chr1: "w/", chr2: "+/+", chr3: "+/+", chr4: "+/+", cross: cross)
    fly.save!(validate: false)
    sign_in_as @owner
    assert_no_difference("Cross.count") { follow_on(cross.id, male_id: fly.id.to_s, female_id: fly.id.to_s) }
    assert_includes flash[:alert], "incomplete genotype"
  end
end
