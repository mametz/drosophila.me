class StocksController < ApplicationController
  before_action :set_stock, only: [:show, :edit, :update, :destroy]
  #before_action :correct_user, only: [:edit,:update,:destroy,:show]
  before_action :logged_user, only: [:index, :new, :create, :show]

  # GET /stocks
  # GET /stocks.json
  def index
    @stocks = Stock.all
  end

  # GET /stocks/1
  # GET /stocks/1.json
  def show
  end

  # GET /stocks/new
  def new
    @stock = Stock.new
  end

  # GET /stocks/1/edit
  def edit
  end

  # POST /stocks
  # POST /stocks.json
  def create
    @fly = Fly.find(params[:fly_to_stock])

    @stock = Stock.new(:number => 0, :name => "", :fly_id => @fly.id, :lab_id => "", 
                       :user_id => "", :comment => "", :date_established => "", 
                       :room_id => "", :reference => "", :received_from => "")

    respond_to do |format|
      if @stock.save
        format.html { redirect_to stocks_path, notice: 'Stock was successfully created.' }
        format.json { render :show, status: :created, location: @stock }
      else
        format.html { redirect_to root_path }
        format.json { render json: @stock.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /stocks/1
  # PATCH/PUT /stocks/1.json
  def update
    respond_to do |format|
      if @stock.update(stock_params)
        format.html { redirect_to @stock, notice: 'Stock was successfully updated.' }
        format.json { render :show, status: :ok, location: @stock }
      else
        format.html { render :edit }
        format.json { render json: @stock.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /stocks/1
  # DELETE /stocks/1.json
  def destroy
    @stock.destroy
    respond_to do |format|
      format.html { redirect_to stocks_url, notice: 'Stock was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_stock
      @stock = Stock.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def stock_params
      params.require(:stock).permit(:number, :name, :fly_id, :lab_id, :user_id, :comment, :date_established, :room_id, :reference, :received_from)
    end
    def correct_user
        if user_signed_in?
            if current_user.id != @stock.user_id
                redirect_to root_url
            end
        else
           redirect_to root_url
        end
    end
    def logged_user
        if user_signed_in?

        else
           redirect_to root_url, notice: 'You need to be logged in.'
        end
    end
end
