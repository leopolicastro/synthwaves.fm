module API
  module Internal
    class BaseController < ActionController::API
      before_action :authenticate_internal!

      private

      def authenticate_internal!
        token = request.headers["Authorization"]&.delete_prefix("Bearer ")
        head :unauthorized unless token.present? && ActiveSupport::SecurityUtils.secure_compare(token, internal_api_token)
      end

      def internal_api_token
        ENV.fetch("LIQUIDSOAP_API_TOKEN") { Rails.application.credentials.dig(:liquidsoap, :api_token) || "" }
      end
    end
  end
end
