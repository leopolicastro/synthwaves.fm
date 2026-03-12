module FeatureFlagged
  extend ActiveSupport::Concern

  class_methods do
    def require_feature(flag, **options)
      before_action(**options) do
        unless Flipper.enabled?(flag, Current.user)
          redirect_to root_path, alert: "This feature is not available."
        end
      end
    end
  end
end
