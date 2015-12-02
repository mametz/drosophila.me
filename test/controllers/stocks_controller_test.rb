require 'test_helper'

class StocksControllerTest < ActionController::TestCase
  setup do
    @stock = stocks(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:stocks)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create stock" do
    assert_difference('Stock.count') do
      post :create, stock: { comment: @stock.comment, date_established: @stock.date_established, fly_id: @stock.fly_id, lab_id: @stock.lab_id, name: @stock.name, number: @stock.number, received_from: @stock.received_from, reference: @stock.reference, room_id: @stock.room_id, user_id: @stock.user_id }
    end

    assert_redirected_to stock_path(assigns(:stock))
  end

  test "should show stock" do
    get :show, id: @stock
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @stock
    assert_response :success
  end

  test "should update stock" do
    patch :update, id: @stock, stock: { comment: @stock.comment, date_established: @stock.date_established, fly_id: @stock.fly_id, lab_id: @stock.lab_id, name: @stock.name, number: @stock.number, received_from: @stock.received_from, reference: @stock.reference, room_id: @stock.room_id, user_id: @stock.user_id }
    assert_redirected_to stock_path(assigns(:stock))
  end

  test "should destroy stock" do
    assert_difference('Stock.count', -1) do
      delete :destroy, id: @stock
    end

    assert_redirected_to stocks_path
  end
end
