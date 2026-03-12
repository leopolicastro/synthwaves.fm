module AdminAuthorization
  extend ActiveSupport::Concern

  private

  def require_admin
    redirect_to root_path, alert: "Not authorized." unless Current.user&.admin?
  end
end
