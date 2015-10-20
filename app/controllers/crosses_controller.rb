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
    @flym = Fly.find(@cross.male_id)
    @flyf = Fly.find(@cross.female_id)

    if @flym.chr1 == @flyf.chr1
      chr1 = [@flym.chr1]
    else
      chrm = @flym.chr1.split('/')
      chrf = @flym.chr1.split('/')

      chr1 = [[chrm[0],chrf[0]],[chrm[0],chrf[1]],[chrm[1],chrf[0]],[chrm[1],chrf[1]]]
    end
    if @flym.chr2 == @flyf.chr2
      chr2 = [@flym.chr2]
    else
      chrm = @flym.chr2.split('/')
      chrf = @flym.chr2.split('/')

      chr2 = [[chrm[0],chrf[0]],[chrm[0],chrf[1]],[chrm[1],chrf[0]],[chrm[1],chrf[1]]]
    end
    if @flym.chr3 == @flyf.chr3
      chr3 = [@flym.chr3]
    else
      chrm = @flym.chr3.split('/')
      chrf = @flym.chr3.split('/')

      chr3 = [[chrm[0],chrf[0]],[chrm[0],chrf[1]],[chrm[1],chrf[0]],[chrm[1],chrf[1]]]
    end
    if @flym.chr4 == @flyf.chr4
      chr4 = [@flym.chr4]
    else
      chrm = @flym.chr4.split('/')
      chrf = @flym.chr4.split('/')

      chr4 = [[chrm[0],chrf[0]],[chrm[0],chrf[1]],[chrm[1],chrf[0]],[chrm[1],chrf[1]]]
    end

    @progeny = chr1.product(chr2,chr3,chr4)

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

    require 'securerandom'
    random_string = SecureRandom.hex

    @cross = Cross.new(:link => random_string, :description => params[:description])

    respond_to do |format|
      if @cross.save

        if params[:m_X] == "+/-"
          params[:m_X] = "+"
        end
        if params[:m_II] == "+/+"
          params[:m_II] = "+"
        end
        if params[:m_III] == "+/+"
          params[:m_III] = "+"
        end
        if params[:m_IV] == "+/+"
          params[:m_IV] = "+"
        end

        if params[:f_X] == "+/+"
          params[:f_X] = "+"
        end
        if params[:f_II] == "+/+"
          params[:f_II] = "+"
        end
        if params[:f_III] == "+/+"
          params[:f_III] = "+"
        end
        if params[:f_IV] == "+/+"
          params[:f_IV] = "+"
        end

        @flym = Fly.new(:chr1 => params[:m_X], :chr2 => params[:m_II], :chr3 => params[:m_III], :chr4 => params[:m_IV], :cross_id => @cross.id)
        @flyf = Fly.new(:chr1 => params[:f_X], :chr2 => params[:f_II], :chr3 => params[:f_III], :chr4 => params[:f_IV], :cross_id => @cross.id)

        if @flym.save and @flyf.save

          @cross.update(:male_id => @flym.id, :female_id => @flyf.id)

          format.html { redirect_to @cross, notice: 'Cross was successfully created.' }
          format.json { render :show, status: :created, location: @cross }
        else
          format.html { render :new }
          format.json { render json: @cross.errors, status: :unprocessable_entity }
        end 
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
      params.require(:cross).permit(:description,:m_X,:m_II,:m_III,:m_IV,:f_X,:f_II,:f_III,:f_IV,:lethal,:balancers)
    end
end
