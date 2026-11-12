require "test_helper"

class UsageStatsTest < ActiveSupport::TestCase
  setup do
    @one = users(:one)
    @two = users(:two)
  end

  # Built on each use, so it sees data created during the test.
  def stats = UsageStats.new

  test "guesses countries from email addresses" do
    assert_equal "United States", stats.country_for("a@biology.utah.edu")
    assert_equal "United Kingdom", stats.country_for("a@cam.ac.uk")
    assert_equal "Switzerland", stats.country_for("a@unibas.ch")
    assert_equal "Personal email", stats.country_for("a@gmail.com")
    assert_equal "International (.org)", stats.country_for("a@embl.org")
    assert_equal ".zz", stats.country_for("a@x.zz")
  end

  test "reads devices from browsers" do
    iphone = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1"
    mac = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/131.0 Safari/537.36"
    edge = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0 Safari/537.36 Edg/131.0"
    tablet = "Mozilla/5.0 (Linux; Android 14; SM-X710) AppleWebKit/537.36 Chrome/131.0 Safari/537.36"
    assert_equal %w[Phone Safari iOS], [ stats.device_for(iphone), stats.browser_for(iphone), stats.os_for(iphone) ]
    assert_equal %w[Computer Chrome macOS], [ stats.device_for(mac), stats.browser_for(mac), stats.os_for(mac) ]
    assert_equal %w[Computer Edge Windows], [ stats.device_for(edge), stats.browser_for(edge), stats.os_for(edge) ]
    assert_equal %w[Tablet Android], [ stats.device_for(tablet), stats.os_for(tablet) ]
    assert_equal "Unknown", stats.device_for(nil)
  end

  test "counts active accounts and compares with the period before" do
    @one.crosses.create!(crossdate: Date.current)
    @two.crosses.create!(crossdate: Date.current, created_at: 40.days.ago, updated_at: 40.days.ago)
    overview = stats.overview
    assert_equal({ current: 1, previous: 1 }, overview[:active_30])
    assert_equal 2, overview[:accounts_with_data]
    assert_equal({ current: 1, previous: 1 }, overview[:crosses_30])
  end

  test "places each account in one stage" do
    @one.update_columns(created_at: 2.years.ago)
    @two.update_columns(created_at: 2.years.ago)
    @one.crosses.create!(crossdate: Date.current, created_at: 200.days.ago, updated_at: 200.days.ago)
    assert_equal({ "dormant" => 1, "never" => 1 }, stats.lifecycle)
  end

  test "series have a row for every period" do
    @one.update_columns(created_at: 3.months.ago)
    growth = stats.monthly_growth
    assert_equal 4, growth[:accounts].size
    assert_equal 1, growth[:accounts].first.last
    assert_equal 2, stats.cumulative_accounts.last.last
    assert_equal 90, stats.recent_activity[:active].size
  end

  test "cohorts show who came back" do
    @one.update_columns(created_at: 2.months.ago.beginning_of_month + 1.day)
    @one.crosses.create!(crossdate: Date.current)
    cohort = stats.cohorts("month", 12).find { |row| row[:start] == 2.months.ago.to_date.beginning_of_month }
    assert_equal 1, cohort[:size]
    assert_equal({ 2 => 1.0 }, cohort[:shares])
  end

  test "counts generations, balancers and stock sources" do
    first = @one.crosses.create!(crossdate: Date.current, balancers: "CyO; TM3 ")
    second = @one.crosses.create!(crossdate: Date.current, parent: first, balancers: "CyO")
    @two.crosses.create!(crossdate: Date.current, parent: second, balancers: "cyo")
    assert_equal 1, stats.generations.to_h["3"]
    assert_equal [ "CyO", 2, 1 ], stats.top_list_entries("balancers").first.values_at("name", "uses", "accounts").map { |v| v.is_a?(String) ? v : v.to_i }

    fly = Fly.create!(chr1: "+/+", chr2: "+/+", chr3: "+/+", chr4: "+/+")
    @one.stocks.create!(fly: fly, number: 1, received_from: "Bloomington ")
    @two.stocks.create!(fly: fly, number: 1, received_from: "bloomington")
    source = stats.stock_sources.first
    assert_equal [ 2, 2 ], [ source["stocks"].to_i, source["accounts"].to_i ]
  end

  test "daily visits give stickiness" do
    ActivityDay.record(@one)
    ActivityDay.record(@one)
    ActivityDay.record(@two, day: Date.current - 3)
    engagement = stats.engagement
    assert_equal 1, engagement[:dau_today]
    assert_equal 2, engagement[:mau]
    assert_in_delta (2 / 28.0) / 2, engagement[:stickiness]
    assert_equal 1.5, engagement[:requests_per_visit]
  end
end
