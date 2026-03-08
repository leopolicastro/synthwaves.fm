class Static::LandingController < ApplicationController
  allow_unauthenticated_access only: %i[show]
  layout "landing"

  def show
    redirect_to library_path if resume_session
  end
end
