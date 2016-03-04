class StaticPagesController < ApplicationController
  def home
  	@user_n = User.all.count
  	@cross_n = Cross.all.count * 2
  	@stock_n = Stock.all.count

  end

  def help
  end

  def about
  end
end
