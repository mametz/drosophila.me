class AccountsController < ApplicationController
  def edit
    @user = Current.user
  end

  def update
    @user = Current.user
    if @user.update(account_params)
      redirect_to edit_account_path, notice: "Your account was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    Current.user.destroy!
    cookies.delete(:session_id)
    redirect_to root_path, notice: "Your account was deleted.", status: :see_other
  end

  private

  def account_params
    fields = params.expect(user: [ :email_address, :password, :password_confirmation, :password_challenge ])
    fields[:password_challenge] = fields[:password_challenge].to_s
    fields.delete(:password) if fields[:password].blank?
    fields.delete(:password_confirmation) if fields[:password].blank?
    fields
  end
end
