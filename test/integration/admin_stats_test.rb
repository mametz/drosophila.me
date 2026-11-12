require "test_helper"

class AdminStatsTest < ActionDispatch::IntegrationTest
  BROWSER = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1"

  setup do
    @admin_emails = ENV["ADMIN_EMAILS"]
    ENV["ADMIN_EMAILS"] = " Two@example.com , someone@else.org"
    @admin = users(:two)
    @member = users(:one)
  end

  teardown { ENV["ADMIN_EMAILS"] = @admin_emails }

  def browse(path, method: :get, **options)
    send(method, path, headers: { "User-Agent" => BROWSER }, **options)
  end

  test "only admins can open the stats page" do
    get admin_root_path
    assert_redirected_to new_session_path

    sign_in_as @member
    get admin_root_path
    assert_response :not_found
    browse root_path
    assert_select "a[href=?]", admin_root_path, count: 0

    sign_in_as @admin
    browse root_path
    assert_select "a[href=?]", admin_root_path
  end

  test "the stats page works on an empty site" do
    sign_in_as @admin
    get admin_root_path
    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "the stats page shows every section with data" do
    room = @member.rooms.create!(name: "Warm", temperature: 25)
    fly = Fly.create!(chr1: "+/+", chr2: "Cy/+", chr3: "+/+", chr4: "+/+")
    @member.stocks.create!(fly: fly, number: 1, room: room, received_from: "Bloomington")
    parent = @member.crosses.create!(crossdate: Date.current, balancers: "CyO; TM3", lethal: "Cy", created_at: 2.years.ago)
    @member.crosses.create!(crossdate: Date.current, parent: parent, shared: false)
    @member.sessions.create!(user_agent: BROWSER)
    sign_in_as @admin
    browse crosses_path

    get admin_root_path
    assert_response :success
    %w[overview growth engagement retention accounts places rhythm features pages devices system].each do |section|
      assert_select "section##{section}"
    end
    assert_select "svg.chart", minimum: 8
    assert_select "td", text: "example.com"
    assert_match "Bloomington", response.body
    assert_match "CyO", response.body
    assert_match "Cross list", response.body
    assert_no_match "one@example.com", response.body
  end

  test "visits are counted without storing who saw which page" do
    sign_in_as @member
    assert_difference -> { PageView.count } => 1, -> { ActivityDay.count } => 1 do
      browse crosses_path
      browse crosses_path
    end
    view = PageView.last
    assert_equal [ "crosses#index", true, 2 ], [ view.page, view.signed_in, view.views ]
    assert_equal 2, @member.activity_days.sole.requests

    browse stocks_path(format: :csv)
    assert PageView.exists?(page: "stocks#index.csv")

    sign_out
    browse root_path
    assert PageView.exists?(page: "static_pages#home", signed_in: false)
  end

  test "bots, errors and the stats page itself aren't counted" do
    get root_path, headers: { "User-Agent" => "Googlebot/2.1" }
    get root_path
    sign_in_as @member
    browse "/crosses/doesnotexist"
    sign_in_as @admin
    browse admin_root_path
    assert_equal 0, PageView.count
  end

  test "deleting an account still works and removes its activity" do
    sign_in_as @member
    browse crosses_path
    assert_difference -> { User.count } => -1, -> { ActivityDay.count } => -1 do
      browse account_path, method: :delete, params: { password_challenge: "password" }
    end
    assert_redirected_to root_path
  end
end
