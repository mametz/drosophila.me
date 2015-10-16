require 'test_helper'

class CrossesControllerTest < ActionController::TestCase
  setup do
    @cross = crosses(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:crosses)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create cross" do
    assert_difference('Cross.count') do
      post :create, cross: { female_id: @cross.female_id, link: @cross.link, male_id: @cross.male_id }
    end

    assert_redirected_to cross_path(assigns(:cross))
  end

  test "should show cross" do
    get :show, id: @cross
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @cross
    assert_response :success
  end

  test "should update cross" do
    patch :update, id: @cross, cross: { female_id: @cross.female_id, link: @cross.link, male_id: @cross.male_id }
    assert_redirected_to cross_path(assigns(:cross))
  end

  test "should destroy cross" do
    assert_difference('Cross.count', -1) do
      delete :destroy, id: @cross
    end

    assert_redirected_to crosses_path
  end
end
