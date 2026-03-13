class PlayHistoriesController < ApplicationController
  def index
    recent = Current.user.play_histories
      .includes(track: [:artist, :album])
      .order(played_at: :desc)
      .limit(50)
    @grouped_histories = recent.group_by { |ph| ph.track.album }
  end

  def create
    track = Current.user.tracks.find(params[:track_id])
    Current.user.play_histories.create!(track: track, played_at: Time.current)
    head :ok
  end
end
