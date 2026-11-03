class StaticPagesController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session

  def home
    @user_count = User.count
    @cross_count = Cross.count
    @stock_count = Stock.count
  end

  def team
  end
end
