module StorageHelper
  def storage_preconnect_tag
    service = ActiveStorage::Blob.service

    # Unwrap mirror services to get the primary
    service = service.primary if service.respond_to?(:primary)

    return unless service.respond_to?(:bucket)

    endpoint = service.bucket.client.config.endpoint.to_s
    tag.link(rel: "preconnect", href: endpoint)
  end
end
