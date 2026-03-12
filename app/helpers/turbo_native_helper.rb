module TurboNativeHelper
  def turbo_native_app?
    request.user_agent.to_s.include?("Turbo Native")
  end

  def native_url_builder
    @native_url_builder ||= SubsonicUrlBuilder.new(Current.user, base_url: request.base_url) if turbo_native_app? && Current.user
  end
end
