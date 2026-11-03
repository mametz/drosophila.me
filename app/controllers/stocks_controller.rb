class StocksController < ApplicationController
  before_action :set_stock, only: %i[show edit update destroy]

  def index
    @stocks = Current.user.stocks.by_number.includes(:room, :fly)
    respond_to do |format|
      format.html
      format.csv { send_data tsv(@stocks), filename: "stock-list.tsv", type: "text/csv" }
    end
  end

  def show
  end

  def new
    @stock = Current.user.stocks.new
  end

  def edit
  end

  def create
    @stock = Current.user.stocks.new(stock_params)
    @stock.fly = Fly.from_chromosomes(typed_chromosomes)
    if @stock.save
      redirect_to @stock, notice: "Stock was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def from_fly
    fly = Fly.find(params[:fly_id])
    raise ActiveRecord::RecordNotFound unless Current.user.can_use_fly?(fly)

    Current.user.stocks.create!(fly: fly, number: 0)
    redirect_to stocks_path, notice: "Stock was successfully created."
  end

  def update
    if @stock.update(stock_params)
      redirect_to @stock, notice: "Stock was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @stock.destroy!
    redirect_to stocks_path, notice: "Stock was deleted.", status: :see_other
  end

  private

  def set_stock
    @stock = Current.user.stocks.find(params[:id])
  end

  def stock_params
    params.expect(stock: [ :number, :name, :comment, :date_established, :room_id, :reference, :received_from ])
  end

  def typed_chromosomes
    fields = params.expect(genotype: [ :X, :II, :III, :IV ])
    %i[X II III IV].map { |name| Genotype.homozygous(fields[name].to_s.strip) }
  end

  def tsv(stocks)
    headers = [ "Room", "Stock number", "X chromosome", "II chromosome", "III chromosome", "IV chromosome",
                "Comment", "Reference", "Received from", "Date established" ]
    CSV.generate(col_sep: "\t") do |rows|
      rows << headers
      stocks.each do |stock|
        rows << [ stock.room&.name, stock.number, *stock.fly.chromosomes, stock.comment.presence,
                  stock.reference.presence, stock.received_from.presence, stock.date_established ]
      end
    end
  end
end
