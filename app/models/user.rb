class User < ActiveRecord::Base
  include Gravtastic
  gravtastic
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :trackable, :validatable,
    :omniauthable, :omniauth_providers => [:facebook, :twitter]

  has_many :crosses, :dependent => :destroy
  has_many :stocks, :dependent => :destroy
  has_many :rooms, :dependent => :destroy
end
