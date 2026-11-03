require "test_helper"

class StocksTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @other = users(:two)
    @fly = Fly.create!(chr1: "+/+", chr2: "Cy/+", chr3: "+/+", chr4: "+/+")
    @room = @owner.rooms.create!(name: "18C", temperature: 18)
    @stock = @owner.stocks.create!(fly: @fly, number: 1, room: @room, comment: "keep")
  end

  def new_stock(**fields)
    { stock: { number: 7, room_id: "" }.merge(fields), genotype: { X: "w", II: "Cy/+", III: "+/+", IV: "+/+" } }
  end

  test "everything needs login" do
    [ stocks_path, new_stock_path, stock_path(@stock), rooms_path ].each do |path|
      get path
      assert_redirected_to new_session_path, path
    end
    assert_no_difference("Stock.count") { post stocks_path, params: new_stock }
    assert_no_difference("Stock.count") { post stock_from_fly_path(@fly) }
    assert_redirected_to new_session_path
  end

  test "creating a stock stores its genotype" do
    sign_in_as @owner
    assert_difference("Stock.count", 1) { post stocks_path, params: new_stock }
    stock = Stock.order(:id).last
    assert_equal @owner, stock.user
    assert_equal %w[w/w Cy/+ +/+ +/+], stock.fly.chromosomes
    assert_redirected_to stock_path(stock)
  end

  test "a bad genotype shows the form again" do
    sign_in_as @owner
    assert_no_difference([ "Stock.count", "Fly.count" ]) do
      post stocks_path, params: { stock: { number: 1 }, genotype: { X: "a/b/c", II: "+/+", III: "+/+", IV: "+/+" } }
    end
    assert_response :unprocessable_entity
  end

  test "stock_it is POST only and limited to your own flies" do
    cross = @owner.crosses.create!(crossdate: Date.current)
    fly = Fly.create!(chr1: "+/+", chr2: "+/+", chr3: "+/+", chr4: "+/+", cross: cross)
    sign_in_as @owner
    assert_difference("Stock.count", 1) { post stock_from_fly_path(fly) }
    assert_redirected_to stocks_path
    get "/stocks/n/#{fly.id}"
    assert_response :not_found

    sign_out
    sign_in_as @other
    assert_no_difference("Stock.count") { post stock_from_fly_path(fly) }
    assert_response :not_found
  end

  test "other people's stocks and rooms are not reachable" do
    sign_in_as @other
    get stock_path(@stock)
    assert_response :not_found
    patch stock_path(@stock), params: { stock: { comment: "mine now" } }
    assert_response :not_found
    delete stock_path(@stock)
    assert_response :not_found
    get edit_room_path(@room)
    assert_response :not_found
    delete room_path(@room)
    assert_response :not_found
    assert_equal "keep", @stock.reload.comment
  end

  test "a stock cannot be moved to another user or into their room" do
    sign_in_as @owner
    other_room = @other.rooms.create!(name: "theirs")
    patch stock_path(@stock), params: { stock: { user_id: @other.id, comment: "changed" } }
    assert_equal @owner, @stock.reload.user
    assert_equal "changed", @stock.comment

    patch stock_path(@stock), params: { stock: { room_id: other_room.id } }
    assert_response :unprocessable_entity
    assert_equal @room, @stock.reload.room
  end

  test "index renders and the download is a TSV of your stocks" do
    @other.stocks.create!(fly: @fly, number: 99)
    sign_in_as @owner
    get stocks_path
    assert_response :success
    get stocks_path(format: :csv)
    assert_response :success
    assert_includes response.headers["Content-Disposition"], "stock-list.tsv"
    lines = response.body.lines.map { |line| line.chomp.split("\t", -1) }
    assert_equal "Room", lines[0][0]
    assert_equal [ "18C", "1", "+/+", "Cy/+", "+/+", "+/+", "keep" ], lines[1].first(7)
    assert_equal 2, lines.size
  end

  test "rooms can be added, edited and deleted, and stocks survive" do
    sign_in_as @owner
    assert_difference("Room.count", 1) { post rooms_path, params: { room: { name: "25C", temperature: 25 } } }
    patch room_path(@room), params: { room: { name: "cold" } }
    assert_equal "cold", @room.reload.name
    get rooms_path
    assert_response :success
    delete room_path(@room)
    assert_nil @stock.reload.room_id
  end
end
