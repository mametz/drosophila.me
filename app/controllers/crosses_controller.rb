class CrossesController < ApplicationController
  before_action :set_cross, only: [:show, :edit, :update, :destroy]

  # GET /crosses
  # GET /crosses.json
  def index
    @crosses = Cross.all
  end

  # GET /crosses/1
  # GET /crosses/1.json
  def show
  end

  # GET /crosses/new
  def new
    @cross = Cross.new
  end

  # GET /crosses/1/edit
  def edit
  end

  # POST /crosses
  # POST /crosses.json
  def create
    @cross = Cross.new(cross_params)

    respond_to do |format|
      if @cross.save
        format.html { redirect_to @cross, notice: 'Cross was successfully created.' }
        format.json { render :show, status: :created, location: @cross }
      else
        format.html { render :new }
        format.json { render json: @cross.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /crosses/1
  # PATCH/PUT /crosses/1.json
  def update
    respond_to do |format|
      if @cross.update(cross_params)
        format.html { redirect_to @cross, notice: 'Cross was successfully updated.' }
        format.json { render :show, status: :ok, location: @cross }
      else
        format.html { render :edit }
        format.json { render json: @cross.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /crosses/1
  # DELETE /crosses/1.json
  def destroy
    @cross.destroy
    respond_to do |format|
      format.html { redirect_to crosses_url, notice: 'Cross was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_cross
      @cross = Cross.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def cross_params
      params.require(:cross).permit(:male_id, :female_id, :link)
    end
end
