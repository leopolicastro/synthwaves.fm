class API::Import::DirectUploadsController < API::Import::BaseController
  before_action :set_active_storage_url_options

  def create
    blob = ActiveStorage::Blob.create_before_direct_upload!(
      filename: params[:filename],
      byte_size: params[:byte_size],
      checksum: params[:checksum],
      content_type: params[:content_type] || "video/mp4"
    )

    render json: {
      signed_id: blob.signed_id,
      direct_upload: {
        url: blob.service_url_for_direct_upload,
        headers: blob.service_headers_for_direct_upload
      }
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: {error: e.message}, status: :unprocessable_entity
  end

  private

  def set_active_storage_url_options
    ActiveStorage::Current.url_options = {protocol: request.protocol, host: request.host, port: request.port}
  end
end
