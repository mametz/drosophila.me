class CrossesController < ApplicationController
  PUBLIC_ACTIONS = %i[show chromosome punnett history qr].freeze

  allow_unauthenticated_access only: PUBLIC_ACTIONS
  before_action :resume_session, only: PUBLIC_ACTIONS
  before_action :set_visible_cross, only: PUBLIC_ACTIONS + [ :copy ]
  before_action :set_owned_cross, only: %i[update destroy]

  def index
    @crosses = Current.user.crosses.recent.includes(:male_fly, :female_fly)
  end

  def show
    @progeny = @cross.viable_progeny
  end

  def chromosome
    sets = @cross.progeny.map { |fly| fly.genotype.allele_sets }
    @chromosome_lists = (0..3).map { |index| chromosome_list(sets.map { |fly_sets| fly_sets[index] }.uniq) }
    @male_x = @chromosome_lists[0].select { |alleles| alleles.include?("-") }
    @female_x = @chromosome_lists[0] - @male_x
    @male_x, @female_x = @chromosome_lists[0], @chromosome_lists[0] if @male_x.empty?
  end

  def punnett
    @square = PunnettSquare.new(@cross.male_fly.chromosomes, @cross.female_fly.chromosomes)
  end

  def history
    @crosses = @cross.lineage.select { |cross| cross.visible_to?(Current.user) }
    @parent_fly_ids = @crosses.flat_map { |cross| [ cross.male_fly_id, cross.female_fly_id ] }
  end

  def qr
    @qr_svg = RQRCode::QRCode.new(short_url(@cross)).as_svg(module_size: 8, viewbox: true, use_path: true)
  end

  def new
    @cross = Cross.new(crossdate: Date.current)
  end

  def create
    builder = CrossBuilder.new(user: Current.user, params: cross_params)
    if builder.save
      redirect_to short_path(builder.cross), notice: "Cross was successfully created."
    elsif cross_params[:parent].to_s == "stock"
      redirect_to stocks_path, alert: builder.errors.to_sentence
    elsif cross_params[:parent].to_i >= 1
      parent = Current.user.crosses.find_by(id: cross_params[:parent])
      redirect_to(parent ? short_path(parent) : crosses_path, alert: builder.errors.to_sentence)
    else
      @cross = Cross.new(crossdate: Date.current)
      flash.now[:alert] = builder.errors.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @cross.update!(shared: params.expect(cross: [ :shared ])[:shared])
    redirect_to short_path(@cross), notice: @cross.shared? ? "Anyone with the link can see this cross." : "Only you can see this cross now."
  end

  def destroy
    @cross.destroy!
    redirect_to crosses_path, notice: "Cross was deleted.", status: :see_other
  end

  def copy
    copy = @cross.copy_for(Current.user)
    redirect_to short_path(copy), notice: "Cross was copied to your collection."
  end

  private

  def set_visible_cross
    @cross = Cross.find_by!(slug: params[:id])
    raise ActiveRecord::RecordNotFound unless @cross.visible_to?(Current.user)
  end

  def set_owned_cross
    @cross = Current.user.crosses.find_by!(slug: params[:id])
  end

  def chromosome_list(sets)
    sets.reject { |alleles| Genotype.lethal_chromosome?(alleles, @cross.balancer_list, @cross.lethal_list) }
  end

  def cross_params
    params.expect(cross: [ :description, :balancers, :lethal, :crossdate, :parent, :male_id, :female_id,
                           :X, :II, :III, :IV, :m_X, :m_II, :m_III, :m_IV, :f_X, :f_II, :f_III, :f_IV ])
  end
end
