class Stock < ApplicationRecord
  belongs_to :user
  belongs_to :fly, validate: true
  belongs_to :room, optional: true

  validate :room_belongs_to_user

  scope :by_number, -> { order(:number, :id) }

  private

  def room_belongs_to_user
    errors.add(:room, "was not found") if room && room.user_id != user_id
  end
end
