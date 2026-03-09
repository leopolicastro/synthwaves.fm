class FoldersController < ApplicationController
  before_action :set_folder, only: [:show, :edit, :update, :destroy]

  def new
    @folder = Folder.new
    @existing_folders = Current.user.folders.order(:name)
  end

  def create
    folder_name = params[:folder_name].to_s.strip
    uploaded_files = Array(params[:video_files]).reject(&:blank?)

    if folder_name.blank?
      @folder = Folder.new
      @folder.errors.add(:name, "can't be blank")
      @existing_folders = Current.user.folders.order(:name)
      render :new, status: :unprocessable_content
      return
    end

    if uploaded_files.empty?
      @folder = Folder.new(name: folder_name)
      @folder.errors.add(:base, "At least one video file is required")
      @existing_folders = Current.user.folders.order(:name)
      render :new, status: :unprocessable_content
      return
    end

    season_number = params[:season_number].presence&.to_i

    ActiveRecord::Base.transaction do
      @folder = Current.user.folders.find_or_create_by!(name: folder_name)

      uploaded_files.each_with_index do |file, index|
        parsed = FilenameEpisodeParser.parse(file.original_filename, default_season: season_number)
        file_format = file.original_filename[/\.\w+$/]&.delete(".")

        video = @folder.videos.new(
          user: Current.user,
          title: parsed.title.presence || file.original_filename.sub(/\.\w+$/, ""),
          season_number: parsed.season_number || season_number,
          episode_number: parsed.episode_number || (index + 1),
          file_format: file_format,
          file_size: file.size,
          status: "processing"
        )
        video.file.attach(file)
        video.save!
      end
    end

    redirect_to @folder, notice: "#{uploaded_files.size} video(s) uploaded to #{@folder.name}."
  rescue ActiveRecord::RecordInvalid => e
    @folder ||= Folder.new(name: folder_name)
    @folder.errors.add(:base, e.message)
    @existing_folders = Current.user.folders.order(:name)
    render :new, status: :unprocessable_content
  end

  def show
    @videos_by_season = @folder.videos.ready.ordered.group_by(&:season_number)
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
