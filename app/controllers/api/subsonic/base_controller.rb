class API::Subsonic::BaseController < ActionController::API
  include SubsonicAuthentication
  include SubsonicResponseFormatting
end
