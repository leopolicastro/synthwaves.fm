module SubsonicAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_subsonic!
  end

  private

  def authenticate_subsonic!
    username = params[:u]
    @current_user = User.find_by(email_address: username)

    unless @current_user && valid_credentials?
      render_subsonic_error(40, "Wrong username or password")
    end
  end

  def valid_credentials?
    if params[:t].present? && params[:s].present?
      expected = Digest::MD5.hexdigest("#{@current_user.subsonic_password}#{params[:s]}")
      ActiveSupport::SecurityUtils.secure_compare(expected, params[:t])
    elsif params[:p].present?
      password = params[:p]
      password = password.sub(/^enc:/, "").scan(/../).map { |x| x.hex.chr }.join if password.start_with?("enc:")
      ActiveSupport::SecurityUtils.secure_compare(@current_user.subsonic_password.to_s, password.to_s)
    else
      false
    end
  end

  def current_user
    @current_user
  end
end
