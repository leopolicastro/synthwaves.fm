module AuthenticationHelpers
  def login_user(user)
    post "/session", params: {email_address: user.email_address, password: user.password}
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end
