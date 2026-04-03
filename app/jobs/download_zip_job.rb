require "zip"

class DownloadZipJob < ApplicationJob
  queue_as :default

  TRACKS_PER_ZIP = 200

  def perform(download_id)
    @download = Download.find(download_id)
    return if @download.cancelled?

    tracks = collect_tracks
    tracks = tracks.select { |t| t.audio_file.attached? }

    if tracks.empty?
      @download.update!(status: "failed", error_message: "No downloadable tracks found.")
      @download.broadcast_status
      return
    end

    if @download.downloadable_type == "Library" && tracks.size > TRACKS_PER_ZIP
      build_split_zips(tracks)
    else
      build_zip(tracks, @download)
    end
  rescue => e
    @download.update!(status: "failed", error_message: e.message.truncate(255))
    @download.broadcast_status
    raise
  end

  private

  def collect_tracks
    case @download.downloadable_type
    when "Track"
      [@download.downloadable]
    when "Album"
      @download.downloadable.tracks.order(:disc_number, :track_number).includes(:artist)
    when "Playlist"
      @download.downloadable.playlist_tracks.includes(track: [:artist, :album]).map(&:track)
    when "Library"
      Track.includes(:artist, :album).order(:title)
    end
  end

  def build_split_zips(tracks)
    tracks.each_slice(TRACKS_PER_ZIP).with_index do |batch, index|
      dl = if index == 0
        @download
      else
        @download.user.downloads.create!(
          downloadable_type: "Library",
          status: "pending"
        ).tap { |d| d.broadcast_append }
      end
      build_zip(batch, dl, part: index + 1)
    end
  end

  def build_zip(tracks, download, part: nil)
    download.update!(status: "processing", total_tracks: tracks.size, processed_tracks: 0)
    download.broadcast_status

    dir = Rails.root.join("tmp", "downloads")
    FileUtils.mkdir_p(dir)
    zip_path = dir.join("download_#{download.id}_#{Time.current.to_i}.zip")

    used_names = Hash.new(0)

    Zip::File.open(zip_path.to_s, create: true) do |zipfile|
      tracks.each_with_index do |track, idx|
        break if download.reload.cancelled?

        track.audio_file.open do |tempfile|
          entry_name = zip_entry_name(track, download.downloadable_type)
          entry_name = deduplicate_name(entry_name, used_names)
          zipfile.get_output_stream(entry_name) do |os|
            IO.copy_stream(tempfile.path, os)
          end
        end

        download.increment!(:processed_tracks)
        download.broadcast_status if (idx + 1) % 5 == 0 || idx == tracks.size - 1
      end
    end

    base_filename = download.filename
    if part
      base_filename = base_filename.sub(/\.zip$/, " Part #{part}.zip")
    end

    download.file.attach(
      io: File.open(zip_path),
      filename: base_filename,
      content_type: "application/zip"
    )
    download.update!(status: "ready")
    download.broadcast_status
  ensure
    FileUtils.rm_f(zip_path) if zip_path
  end

  def zip_entry_name(track, type)
    ext = track.file_format.presence || "mp3"
    case type
    when "Album"
      num = track.track_number ? format("%02d", track.track_number) : "00"
      "#{num} - #{FilenameUtils.sanitize(track.title)}.#{ext}"
    when "Playlist"
      "#{FilenameUtils.sanitize(track.artist.name)} - #{FilenameUtils.sanitize(track.title)}.#{ext}"
    when "Library"
      "#{FilenameUtils.sanitize(track.artist.name)}/#{FilenameUtils.sanitize(track.album.title)}/#{FilenameUtils.sanitize(track.title)}.#{ext}"
    else
      "#{FilenameUtils.sanitize(track.artist.name)} - #{FilenameUtils.sanitize(track.title)}.#{ext}"
    end
  end

  def deduplicate_name(name, used_names)
    used_names[name] += 1
    count = used_names[name]
    return name if count == 1
    ext = File.extname(name)
    base = name.chomp(ext)
    "#{base} (#{count})#{ext}"
  end
end
