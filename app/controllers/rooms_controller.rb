class RoomsController < ApplicationController
  before_action :set_room, only: %i[edit update destroy]

  def index
    @rooms = Current.user.rooms.order(:name)
  end

  def new
    @room = Current.user.rooms.new
  end

  def edit
  end

  def create
    @room = Current.user.rooms.new(room_params)
    if @room.save
      redirect_to rooms_path, notice: "Room was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @room.update(room_params)
      redirect_to rooms_path, notice: "Room was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @room.destroy!
    redirect_to rooms_path, notice: "Room was deleted.", status: :see_other
  end

  private

  def set_room
    @room = Current.user.rooms.find(params[:id])
  end

  def room_params
    params.expect(room: [ :name, :temperature ])
  end
end
