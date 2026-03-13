class Static::PrivacyController < ApplicationController
  allow_unauthenticated_access only: %i[show]
  layout "landing"

  def show
  end
end
