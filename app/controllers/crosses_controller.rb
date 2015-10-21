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
    flym = Fly.find(@cross.male_id)
    flyf = Fly.find(@cross.female_id)

    @parent_male = [flym.chr1.split('/').to_set, flym.chr2.split('/').to_set, flym.chr3.split('/').to_set, flym.chr4.split('/').to_set]
    @parent_female = [flyf.chr1.split('/').to_set, flyf.chr2.split('/').to_set, flyf.chr3.split('/').to_set, flyf.chr4.split('/').to_set]

    prog = Fly.where("cross_id = ?", @cross.id)

    if @cross.male_id == @cross.female_id
      prog = prog.drop(1)
    else
      prog = prog.drop(2)
    end

    @progeny = []
    @prog_id = []
    prog.each do |n|
      @progeny.append([n.chr1.split('/').to_set, n.chr2.split('/').to_set, n.chr3.split('/').to_set, n.chr4.split('/').to_set])
      @prog_id.append(n.id)
    end

    @balancers = @cross.balancers.split(',')
    @lethal = @cross.lethal.split(',')

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

    @cross = Cross.new(:link => random_string, :description => params[:description], 
                        :balancers => params[:balancers], :lethal => params[:lethal])

    respond_to do |format|
      if @cross.save

        if params[:m_X] == "+/-" and params[:f_X] == "+/+"
          params[:m_X] = "+/+"
        end

        @flym = Fly.new(:chr1 => params[:m_X], :chr2 => params[:m_II], :chr3 => params[:m_III], :chr4 => params[:m_IV], :cross_id => @cross.id)
        @flyf = Fly.new(:chr1 => params[:f_X], :chr2 => params[:f_II], :chr3 => params[:f_III], :chr4 => params[:f_IV], :cross_id => @cross.id)

        if @flym.save and @flyf.save

          chrm = @flym.chr1.split('/')
          chrf = @flyf.chr1.split('/')
          chr1 = [Set[chrm[0],chrf[0]],Set[chrm[0],chrf[1]],Set[chrm[1],chrf[0]],Set[chrm[1],chrf[1]]]

          chrm = @flym.chr2.split('/')
          chrf = @flyf.chr2.split('/')
          chr2 = [Set[chrm[0],chrf[0]],Set[chrm[0],chrf[1]],Set[chrm[1],chrf[0]],Set[chrm[1],chrf[1]]]

          chrm = @flym.chr3.split('/')
          chrf = @flyf.chr3.split('/')
          chr3 = [Set[chrm[0],chrf[0]],Set[chrm[0],chrf[1]],Set[chrm[1],chrf[0]],Set[chrm[1],chrf[1]]]

          chrm = @flym.chr4.split('/')
          chrf = @flyf.chr4.split('/')
          chr4 = [Set[chrm[0],chrf[0]],Set[chrm[0],chrf[1]],Set[chrm[1],chrf[0]],Set[chrm[1],chrf[1]]]

          progeny = chr1.product(chr2,chr3,chr4).uniq

          progeny.each do |p|
            out = []
            p.each do |n|
              if n.size == 1
                out.append(n.to_a[0]+"/"+n.to_a[0])
              else
                out.append(n.to_a.join('/'))
              end
            end
            flyp = Fly.new(:chr1 => out[0], :chr2 => out[1], :chr3 => out[2], :chr4 => out[3], :cross_id => @cross.id)
            flyp.save
          end

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
