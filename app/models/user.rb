class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :crosses, dependent: :destroy
  has_many :stocks, dependent: :destroy
  has_many :rooms, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true

  def can_use_fly?(fly)
    (fly.cross && fly.cross.user_id == id) ||
      stocks.exists?(fly_id: fly.id) ||
      crosses.where(male_fly_id: fly.id).or(crosses.where(female_fly_id: fly.id)).exists?
  end

  def gravatar_url(size: 80)
    "https://www.gravatar.com/avatar/#{Digest::MD5.hexdigest(email_address)}?s=#{size}&d=mp"
  end
end
