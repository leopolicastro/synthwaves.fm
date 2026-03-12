class TurboNativeController < ApplicationController
  skip_before_action :require_authentication

  def path_configuration
    render json: {
      settings: {},
      rules: [
        {patterns: [".*"], properties: {context: "default"}}
      ]
    }
  end
end
