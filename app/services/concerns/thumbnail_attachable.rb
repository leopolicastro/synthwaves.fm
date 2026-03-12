module ThumbnailAttachable
  private

  def attach_thumbnail(record, thumbnail_url)
    response = HTTP.get(thumbnail_url)
    return unless response.status.success?

    content_type = response.content_type.mime_type
    extension = case content_type
    when "image/png" then "png"
    when "image/webp" then "webp"
    else "jpg"
    end

    record.cover_image.attach(
      io: StringIO.new(response.body.to_s),
      filename: "cover.#{extension}",
      content_type: content_type
    )
  rescue HTTP::Error
    # Thumbnail download failed — not critical, skip it
  end
end
