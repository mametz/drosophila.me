class FliesController < ApplicationController
  before_action :set_fly, only: [:show, :edit, :update, :destroy]

  # GET /flies
  # GET /flies.json
  def index
    @flies = Fly.all
  end

  # GET /flies/1
  # GET /flies/1.json
  def show
  end

  # GET /flies/new
  def new
    @fly = Fly.new
  end

  # GET /flies/1/edit
  def edit
  end

  # POST /flies
  # POST /flies.json
  def create
    @fly = Fly.new(fly_params)

    respond_to do |format|
      if @fly.save
        format.html { redirect_to @fly, notice: 'Fly was successfully created.' }
        format.json { render :show, status: :created, location: @fly }
      else
        format.html { render :new }
        format.json { render json: @fly.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /flies/1
  # PATCH/PUT /flies/1.json
  def update
    respond_to do |format|
      if @fly.update(fly_params)
        format.html { redirect_to @fly, notice: 'Fly was successfully updated.' }
        format.json { render :show, status: :ok, location: @fly }
      else
        format.html { render :edit }
        format.json { render json: @fly.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /flies/1
  # DELETE /flies/1.json
  def destroy
    @fly.destroy
    respond_to do |format|
      format.html { redirect_to flies_url, notice: 'Fly was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_fly
      @fly = Fly.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def fly_params
      params.require(:fly).permit(:chr1, :chr2, :chr3, :chr4, :cross_id)
    end
end
