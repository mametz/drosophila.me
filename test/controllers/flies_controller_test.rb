require 'test_helper'

class FliesControllerTest < ActionController::TestCase
  setup do
    @fly = flies(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:flies)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create fly" do
    assert_difference('Fly.count') do
      post :create, fly: { chr1: @fly.chr1, chr2: @fly.chr2, chr3: @fly.chr3, chr4: @fly.chr4, cross_id: @fly.cross_id }
    end

    assert_redirected_to fly_path(assigns(:fly))
  end

  test "should show fly" do
    get :show, id: @fly
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @fly
    assert_response :success
  end

  test "should update fly" do
    patch :update, id: @fly, fly: { chr1: @fly.chr1, chr2: @fly.chr2, chr3: @fly.chr3, chr4: @fly.chr4, cross_id: @fly.cross_id }
    assert_redirected_to fly_path(assigns(:fly))
  end

  test "should destroy fly" do
    assert_difference('Fly.count', -1) do
      delete :destroy, id: @fly
    end

    assert_redirected_to flies_path
  end
end
