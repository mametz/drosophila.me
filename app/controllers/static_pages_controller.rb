class StaticPagesController < ApplicationController
  def home
  	@user_n = User.all.count
  	@crosse_n = Cross.all.count
  	@stock_n = Stock.all.count

  end

  def help
  end

  def about
  end
end
