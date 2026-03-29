class PlaylistMergeService
  class Error < StandardError; end

  def self.call(target:, source:)
    new(target: target, source: source).call
  end

  def initialize(target:, source:)
    @target = target
    @source = source
  end

  def call
    raise Error, "Cannot merge a playlist into itself." if @target.id == @source.id
    raise Error, "Cannot merge: source playlist has an active radio station. Stop it first." if @source.radio_station&.active?

    ActiveRecord::Base.transaction do
      existing_ids = @target.playlist_tracks.pluck(:track_id).to_set
      next_position = (@target.playlist_tracks.maximum(:position) || 0) + 1

      @source.playlist_tracks.order(:position).each do |pt|
        next if existing_ids.include?(pt.track_id)
        @target.playlist_tracks.create!(track: pt.track, position: next_position)
        next_position += 1
      end

      @source.destroy!
    end
  end
end
