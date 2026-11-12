class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :crosses, dependent: :destroy
  has_many :stocks, dependent: :destroy
  has_many :rooms, dependent: :destroy
  has_many :activity_days, dependent: :delete_all

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true

  def can_use_fly?(fly)
    (fly.cross && fly.cross.user_id == id) ||
      stocks.exists?(fly_id: fly.id) ||
      crosses.where(male_fly_id: fly.id).or(crosses.where(female_fly_id: fly.id)).exists?
  end

  # Set ADMIN_EMAILS on the server, separated by commas, to open the stats page.
  def admin?
    ENV.fetch("ADMIN_EMAILS", "").split(",").map { |email| email.strip.downcase }.include?(email_address)
  end

  def gravatar_url(size: 80)
    "https://www.gravatar.com/avatar/#{Digest::MD5.hexdigest(email_address)}?s=#{size}&d=mp"
  end
end
