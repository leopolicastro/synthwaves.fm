class API::Subsonic::SystemController < API::Subsonic::BaseController
  def ping
    render_subsonic
  end

  def get_license
    render_subsonic(license: {valid: true, email: current_user.email_address})
  end
end
