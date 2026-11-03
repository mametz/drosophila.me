class CrossesController < ApplicationController
  before_action :set_cross, only: [:show, :edit, :update, :destroy, :history, :copy, :qr, :chromosome, :punnett]
  before_action :correct_user, only: [:edit,:update,:destroy]
  before_action :logged_user, only: [:index, :new, :create, :copy]

  # GET /crosses
  # GET /crosses.json
  def index
    @crosses = Cross.where("user_id = ?", current_user.id)
  end

  def copy
    require 'securerandom'
    link = SecureRandom.hex

    @flym = Fly.find(@cross.male_id)
    @flyf = Fly.find(@cross.female_id)

    @c_flym = Fly.new(:chr1 => @flym.chr1, :chr2 => @flym.chr2, :chr3 => @flym.chr3, :chr4 => @flym.chr4)
    @c_flym.save

    @c_flyf = Fly.new(:chr1 => @flyf.chr1, :chr2 => @flyf.chr2, :chr3 => @flyf.chr3, :chr4 => @flyf.chr4)
    @c_flyf.save

    @c_cross = Cross.new(:male_id => @c_flym.id, :link => link,
                         :female_id => @c_flyf.id, :lethal => @cross.lethal,
                         :balancers => @cross.balancers, :description => @cross.description,
                         :parent => @cross.parent, :user_id => current_user.id, :crossdate => @cross.crossdate)

    flies = Fly.where("cross_id = ? AND id != ? AND id != ?", @cross.id, @cross.male_id, @cross.female_id)

    respond_to do |format|
      if @c_cross.save
        @c_flym.update(:cross_id => @c_cross.id)
        @c_flyf.update(:cross_id => @c_cross.id)
        flies.each do |f|
          @fly = Fly.new(:chr1 => f.chr1, :chr2 => f.chr2, :chr3 => f.chr3, :chr4 => f.chr4, :cross_id => @c_cross.id)
          @fly.save
        end
        format.html { redirect_to short_path(@c_cross.friendly_id), notice: 'Cross was copied to your collection' }
      else
        format.html { render @cross, notice: 'Cross could not be copied.' }
      end
    end

  end

  def history
    @crosses = []
    @crosses.append(Cross.find(@cross.id))
    ncross = Cross.find(@cross.id)

    run = true

    while run;
      if ncross.parent.to_i == 0
        break
      end

      ncross = Cross.find(ncross.parent)
      @crosses.append(ncross)

    end

    @crosses.reverse!
  end

  # GET /crosses/1
  # GET /crosses/1.json
  def show
    require 'securerandom'
    @random_string = SecureRandom.hex

    set_genotypes
    set_balancers

    @current_url = request.original_url

  end

  def chromosome
    require 'securerandom'
    @random_string = SecureRandom.hex

    set_genotypes
    set_balancers

    @current_url = request.original_url
  end

  def punnett

    set_balancers

    male = Genotype.of(Fly.find(@cross.male_id))
    female = Genotype.of(Fly.find(@cross.female_id))

    square = PunnettSquare.new(male.chromosomes, female.chromosomes)
    @par_male = square.par_male
    @par_female = square.par_female
    @p_mal = square.p_mal
    @p_femal = square.p_femal
    @male_chrs = square.male_chrs
    @female_chrs = square.female_chrs

    @parent_male = male.allele_sets
    @parent_female = female.allele_sets
    @current_url = request.original_url

  end

    def qr
      qr_img = RQRCode::QRCode.new("http://drosophila.me/" + @cross.friendly_id.to_s )
      qr_img = qr_img.to_img.resize(500,500)
      qr_fly = MiniMagick::Image.read(qr_img.to_blob)
      fly_img = MiniMagick::Image.open("app/assets/images/small.png")

      qr_result = qr_fly.composite(fly_img) do |c|
        c.compose "Over"    # OverCompositeOp
        c.geometry "+0+0" # copy second_image onto first_image from (20, 20)
      end

      @qr_code = qr_result.to_blob
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

      if cross_params[:parent].to_i >= 1

        @old_cross = Cross.find(cross_params[:parent])

        if cross_params[:male_id] == nil
          redirect_to @old_cross, notice: 'Not all parents were selected.'
          interrup = 1
        elsif cross_params[:female_id] == nil
          redirect_to @old_cross, notice: 'Not all parents were selected.'
          interrup = 1
        elsif cross_params[:male_id] == "male_chr_s"
          if params[:m_X] == nil or params[:m_II] == nil or params[:m_III] == nil or params[:m_IV] == nil
            redirect_to @old_cross, notice: 'Not all chromosomes were selected.'
            interrup = 1
          end
        elsif cross_params[:female_id] == "female_chr_s"
          if params[:f_X] == nil or params[:f_II] == nil or params[:f_III] == nil or params[:f_IV] == nil
            redirect_to @old_cross, notice: 'Not all chromosomes were selected.'
            interrup = 1
          end
        end
      end

      if cross_params[:parent] == "stock"
        if cross_params[:male_id] == nil
          redirect_to stocks_path, notice: 'Not all parents were selected.'
          interrup = 1
        elsif cross_params[:female_id] == nil
          redirect_to stocks_path, notice: 'Not all parents were selected.'
          interrup = 1
        end
      end

      date = Date.new cross_params["crossdate(1i)"].to_i, cross_params["crossdate(2i)"].to_i, cross_params["crossdate(3i)"].to_i

      if interrup != 1
        require 'securerandom'
        random_string = SecureRandom.hex

        if cross_params[:parent].to_i >= 1 or cross_params[:parent] == "stock"
          @cross = Cross.new(:male_id => cross_params[:male_id], :link => cross_params[:link],
                             :female_id => cross_params[:female_id], :lethal => cross_params[:lethal],
                             :balancers => cross_params[:balancers], :description => cross_params[:description],
                             :parent => cross_params[:parent], :user_id => current_user.id, :crossdate => date)
        else
          @cross = Cross.new(:link => random_string, :description => cross_params[:description],
                             :balancers => cross_params[:balancers], :lethal => cross_params[:lethal],
                             :user_id => current_user.id, :crossdate => date)
        end

        respond_to do |format|
          if @cross.save

            if cross_params[:parent].to_i >= 1 or cross_params[:parent] == "stock"

              if cross_params[:male_id] == "new"
                m_x = Genotype.male_x(cross_params[:X])

                if cross_params[:female_id] != "female_chr_s"
                  @flyf = Fly.find(cross_params[:female_id])
                end

                m_x = Genotype.homozygous(m_x)
                chrII = Genotype.homozygous(cross_params[:II])
                chrIII = Genotype.homozygous(cross_params[:III])
                chrIV = Genotype.homozygous(cross_params[:IV])

                @flym = Fly.new(:chr1 => m_x, :chr2 => chrII, :chr3 => chrIII, :chr4 => chrIV, :cross_id => @cross.id)
                @flym.save
              elsif cross_params[:female_id] == "new"
                if cross_params[:male_id] != "male_chr_s"
                  @flym = Fly.find(cross_params[:male_id])
                end

                chrX = Genotype.homozygous(cross_params[:X])
                chrII = Genotype.homozygous(cross_params[:II])
                chrIII = Genotype.homozygous(cross_params[:III])
                chrIV = Genotype.homozygous(cross_params[:IV])

                @flyf = Fly.new(:chr1 => chrX, :chr2 => chrII, :chr3 => chrIII, :chr4 => chrIV, :cross_id => @cross.id)
                @flyf.save
              elsif cross_params[:male_id] != "male_chr_s" and cross_params[:female_id] != "female_chr_s"
                @flym = Fly.find(cross_params[:male_id])
                @flyf = Fly.find(cross_params[:female_id])
              end

              if cross_params[:male_id] == "male_chr_s"
                m_x = Genotype.homozygous(params[:m_X])
                chrII = Genotype.homozygous(params[:m_II])
                chrIII = Genotype.homozygous(params[:m_III])
                chrIV = Genotype.homozygous(params[:m_IV])

                @flym = Fly.new(:chr1 => m_x, :chr2 => chrII, :chr3 => chrIII, :chr4 => chrIV, :cross_id => @cross.id)
                @flym.save
              end
              if cross_params[:female_id] == "female_chr_s"
                m_x = Genotype.homozygous(params[:f_X])
                chrII = Genotype.homozygous(params[:f_II])
                chrIII = Genotype.homozygous(params[:f_III])
                chrIV = Genotype.homozygous(params[:f_IV])

                @flyf = Fly.new(:chr1 => m_x, :chr2 => chrII, :chr3 => chrIII, :chr4 => chrIV, :cross_id => @cross.id)
                @flyf.save
              end

            else
              m_x = Genotype.founder_male_x(cross_params[:m_X])

              m_x = Genotype.homozygous(m_x)
              chr_mII = Genotype.homozygous(cross_params[:m_II])
              chr_mIII = Genotype.homozygous(cross_params[:m_III])
              chr_mIV = Genotype.homozygous(cross_params[:m_IV])
              chr_fX = Genotype.homozygous(cross_params[:f_X])
              chr_fII = Genotype.homozygous(cross_params[:f_II])
              chr_fIII = Genotype.homozygous(cross_params[:f_III])
              chr_fIV = Genotype.homozygous(cross_params[:f_IV])

              @flym = Fly.new(:chr1 => m_x, :chr2 => chr_mII, :chr3 => chr_mIII, :chr4 => chr_mIV, :cross_id => @cross.id)
              @flyf = Fly.new(:chr1 => chr_fX, :chr2 => chr_fII, :chr3 => chr_fIII, :chr4 => chr_fIV, :cross_id => @cross.id)
              @flym.save and @flyf.save
            end

            progeny = CrossCalculator.progeny(Genotype.of(@flym).chromosomes, Genotype.of(@flyf).chromosomes)

            progeny.each do |out|
              flyp = Fly.new(:chr1 => out[0], :chr2 => out[1], :chr3 => out[2], :chr4 => out[3], :cross_id => @cross.id)
              flyp.save
            end
            @cross.update(:male_id => @flym.id, :female_id => @flyf.id)
            format.html { redirect_to short_path(@cross.friendly_id), notice: 'Cross was successfully created.' }
            format.json { render :show, status: :created, location: @cross }

          else
            format.html { render :new }
            format.json { render json: @cross.errors, status: :unprocessable_entity }
          end
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
      if params[:id].is_number?
        redirect_to root_url
      end
      @cross = Cross.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def cross_params
      params.require(:cross).permit(:description,:m_X,:m_II,:m_III,:m_IV,:f_X,:f_II,:f_III,:f_IV,:lethal,:balancers,
                                    :parent,:male_id,:female_id,:link,
                                    :X,:II,:III,:IV,:crossdate)
    end
    def set_genotypes
      @parent_male = Genotype.of(Fly.find(@cross.male_id)).allele_sets
      @parent_female = Genotype.of(Fly.find(@cross.female_id)).allele_sets

      prog = Fly.where("cross_id = ? AND id != ? AND id != ?", @cross.id, @cross.male_id, @cross.female_id)

      @progeny = prog.map { |fly| Genotype.of(fly).allele_sets }
      @prog_id = prog.map(&:id)
      @x_chr = @progeny.map { |sets| [sets[0]] }.uniq
      @II_chr = @progeny.map { |sets| [sets[1]] }.uniq
      @III_chr = @progeny.map { |sets| [sets[2]] }.uniq
      @IV_chr = @progeny.map { |sets| [sets[3]] }.uniq
    end
    def set_balancers
      @balancers = @cross.balancers.split(';')
      @balancer_string = @cross.balancers
      @lethal = @cross.lethal.split(';')
      @lethal_string = @cross.lethal
    end
    def correct_user
      if user_signed_in?
        if current_user.id != @cross.user_id
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
