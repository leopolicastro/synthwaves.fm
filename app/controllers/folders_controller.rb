class FoldersController < ApplicationController
  before_action :set_folder, only: [:show, :edit, :update, :destroy]

  def new
    @folder = Folder.new
    @existing_folders = Current.user.folders.order(:name)
  end

  def create
    folder_name = params[:folder_name].to_s.strip
    signed_blob_ids = Array(params[:signed_blob_ids]).reject(&:blank?)
    filenames = Array(params[:filenames]).reject(&:blank?)

    if folder_name.blank?
      @folder = Folder.new
      @folder.errors.add(:name, "can't be blank")
      @existing_folders = Current.user.folders.order(:name)
      render :new, status: :unprocessable_content
      return
    end

    if signed_blob_ids.empty?
      @folder = Folder.new(name: folder_name)
      @folder.errors.add(:base, "At least one video file is required")
      @existing_folders = Current.user.folders.order(:name)
      render :new, status: :unprocessable_content
      return
    end

    season_number = params[:season_number].presence&.to_i

    ActiveRecord::Base.transaction do
      @folder = Current.user.folders.find_or_create_by!(name: folder_name)

      signed_blob_ids.each_with_index do |signed_id, index|
        filename = filenames[index] || "video_#{index + 1}.mp4"
        parsed = FilenameEpisodeParser.parse(filename, default_season: season_number)
        file_format = filename[/\.\w+$/]&.delete(".")

        blob = ActiveStorage::Blob.find_signed!(signed_id)

        video = @folder.videos.new(
          user: Current.user,
          title: parsed.title.presence || filename.sub(/\.\w+$/, ""),
          season_number: parsed.season_number || season_number,
          episode_number: parsed.episode_number || (index + 1),
          file_format: file_format,
          file_size: blob.byte_size,
          status: "processing"
        )
        video.file.attach(blob)
        video.save!
      end
    end

    redirect_to @folder, notice: "#{signed_blob_ids.size} video(s) uploaded to #{@folder.name}."
  rescue ActiveRecord::RecordInvalid => e
    @folder ||= Folder.new(name: folder_name)
    @folder.errors.add(:base, e.message)
    @existing_folders = Current.user.folders.order(:name)
    render :new, status: :unprocessable_content
  end

  def show
    @query = params[:q]
    @season = params[:season]
    @sort = sort_column(Video, default: "episode_number")
    @direction = sort_direction

    @available_seasons = @folder.videos.ready.where.not(season_number: nil).distinct.pluck(:season_number).sort
    @season_counts = @folder.videos.ready.where.not(season_number: nil).group(:season_number).count

    scope = @folder.videos.ready.search(@query)
    scope = scope.where(season_number: @season) if @season.present?

    scope = if @sort == "episode_number"
      scope.order(season_number: @direction, episode_number: @direction)
    else
      scope.order(@sort => @direction)
    end

    @pagy, @videos = pagy(:offset, scope, limit: 24)
    @processing_count = @folder.videos.where(status: "processing").count
    @failed_count = @folder.videos.where(status: "failed").count
  end

  def edit
  end

  def update
    if @folder.update(folder_params)
      redirect_to @folder, notice: "Folder updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @folder.destroy
    redirect_to tv_path(tab: "videos"), notice: "Folder deleted."
  end

  private

  def set_folder
    @folder = Current.user.folders.find(params[:id])
  end

  def folder_params
    params.require(:folder).permit(:name, :description, :cover_image)
  end
end
