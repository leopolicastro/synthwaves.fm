module API
  module Internal
    class BaseController < ActionController::API
      before_action :authenticate_internal!

      private

      def authenticate_internal!
        expected = internal_api_token
        return head(:unauthorized) unless expected

        token = request.headers["Authorization"]&.delete_prefix("Bearer ")
        head :unauthorized unless token.present? && ActiveSupport::SecurityUtils.secure_compare(token, expected)
      end

      def internal_api_token
        ENV["LIQUIDSOAP_API_TOKEN"].presence || Rails.application.credentials.dig(:liquidsoap, :api_token).presence
      end
    end
  end
end
