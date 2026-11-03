require "test_helper"

class AccountsTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  def form_started(seconds_ago = 10)
    Rails.application.message_verifier(:signup_form).generate(seconds_ago.seconds.ago.to_i)
  end

  def signup(**user)
    { form_started: form_started,
      user: { password: "password123", password_confirmation: "password123" }.merge(user) }
  end

  test "public pages render logged out" do
    [ root_path, team_path, new_session_path, new_registration_path ].each do |path|
      get path
      assert_response :success, path
    end
  end

  test "old Devise paths redirect" do
    get "/users/sign_in"
    assert_redirected_to "/session/new"
    get "/users/sign_up"
    assert_redirected_to "/registration/new"
  end

  test "signing up logs you in" do
    assert_difference("User.count", 1) do
      post registration_path, params: signup(email_address: "New@Example.com")
    end
    assert_redirected_to crosses_path
    follow_redirect!
    assert_response :success
    assert User.exists?(email_address: "new@example.com")
  end

  test "signup form carries the bot checks and a person gets through" do
    get new_registration_path
    assert_select "input[name=website][tabindex='-1']"
    token = css_select("input[name=form_started]").first["value"]
    travel 5.seconds do
      assert_difference("User.count", 1) do
        post registration_path, params: signup(email_address: "person@example.com").merge(form_started: token, website: "")
      end
    end
  end

  test "bots are turned away" do
    [ { website: "http://spam.example" }, { form_started: form_started(0) },
      { form_started: "forged" }, { form_started: nil } ].each do |bot|
      assert_no_difference("User.count", bot.to_s) do
        post registration_path, params: signup(email_address: "bot@example.com").merge(bot)
      end
      assert_redirected_to new_registration_path
    end
  end

  test "weak or duplicate sign-ups are refused" do
    assert_no_difference("User.count") do
      post registration_path, params: signup(email_address: "a@example.com", password: "short", password_confirmation: "short")
    end
    assert_response :unprocessable_entity
    assert_no_difference("User.count") do
      post registration_path, params: signup(email_address: @user.email_address)
    end
    assert_response :unprocessable_entity
  end

  test "a bcrypt hash from Devise logs in unchanged" do
    # Devise stores a plain bcrypt hash, so imported users keep their passwords.
    hash = BCrypt::Password.create("old-devise-password", cost: 4).to_s
    imported = User.new(email_address: "imported@example.com", password_digest: hash)
    imported.save!(validate: false)
    post session_path, params: { email_address: "imported@example.com", password: "old-devise-password" }
    assert_redirected_to root_url
    get edit_account_path
    assert_response :success
  end

  test "changing your profile needs the current password" do
    sign_in_as @user
    patch account_path, params: { user: { email_address: "changed@example.com", password_challenge: "wrong" } }
    assert_response :unprocessable_entity
    assert_not_equal "changed@example.com", @user.reload.email_address

    patch account_path, params: { user: { email_address: "changed@example.com", password_challenge: "password", password: "", password_confirmation: "" } }
    assert_redirected_to edit_account_path
    assert_equal "changed@example.com", @user.reload.email_address
    assert @user.authenticate("password")
  end

  test "deleting your account removes your data but not other people's crosses" do
    other = users(:two)
    mine = @user.crosses.create!(crossdate: Date.current)
    theirs = other.crosses.create!(crossdate: Date.current, parent: mine)
    sign_in_as @user
    assert_difference("User.count", -1) { delete account_path }
    assert_nil theirs.reload.parent_id
    assert_not Cross.exists?(mine.id)
  end
end
