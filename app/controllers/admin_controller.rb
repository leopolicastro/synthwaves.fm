class AdminController < ApplicationController
  include AdminAuthorization

  before_action :require_admin

  private

  def request_authentication
    session[:return_to_after_authenticating] = request.url
    redirect_to "/session/new"
  end
end
