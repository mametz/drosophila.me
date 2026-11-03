class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }

  def new
    @user = User.new
  end

  def create
    @user = User.new(params.expect(user: [ :email_address, :password, :password_confirmation ]))
    if @user.save
      start_new_session_for @user
      redirect_to crosses_path, notice: "Welcome to drosophila.me."
    else
      render :new, status: :unprocessable_entity
    end
  end
end
