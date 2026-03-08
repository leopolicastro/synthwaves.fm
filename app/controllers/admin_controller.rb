class AdminController < ApplicationController
  before_action :require_admin

  private

  def request_authentication
    session[:return_to_after_authenticating] = request.url
    redirect_to "/session/new"
  end

  def require_admin
    redirect_to root_path, alert: "Not authorized." unless Current.user&.admin?
  end
end
