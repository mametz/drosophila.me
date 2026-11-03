class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }
  before_action :turn_away_bots, only: :create
  helper_method :form_started_token

  MINIMUM_FORM_SECONDS = 2

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

  private

  # Most signups on the old site were bots. They tend to fill in every field and
  # submit straight away, so this catches them without a third-party service.
  def turn_away_bots
    return unless params[:website].present? || submitted_too_fast?

    redirect_to new_registration_path, alert: "Please try again."
  end

  def submitted_too_fast?
    started = form_verifier.verified(params[:form_started].to_s)
    started.nil? || Time.current.to_i - started < MINIMUM_FORM_SECONDS
  end

  def form_started_token
    form_verifier.generate(Time.current.to_i)
  end

  def form_verifier
    Rails.application.message_verifier(:signup_form)
  end
end
