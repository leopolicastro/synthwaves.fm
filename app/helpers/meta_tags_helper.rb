module MetaTagsHelper
  DEFAULT_DESCRIPTION = "Self-hosted music streaming. Your music, your server, your rules.".freeze
  DEFAULT_SITE_NAME = "synthwaves.fm".freeze

  def meta_tags
    title = content_for(:meta_title).presence || content_for(:title).presence || DEFAULT_SITE_NAME
    description = content_for(:meta_description).presence || DEFAULT_DESCRIPTION
    image = content_for(:meta_image).presence || "#{request.base_url}/icon-512.png"
    url = content_for(:meta_url).presence || request.original_url
    type = content_for(:meta_type).presence || "website"
    card_type = content_for(:meta_image).present? ? "summary_large_image" : "summary"

    safe_join([
      tag.meta(name: "description", content: description),
      tag.meta(property: "og:title", content: title),
      tag.meta(property: "og:description", content: description),
      tag.meta(property: "og:image", content: image),
      tag.meta(property: "og:url", content: url),
      tag.meta(property: "og:type", content: type),
      tag.meta(property: "og:site_name", content: DEFAULT_SITE_NAME),
      tag.meta(name: "twitter:card", content: card_type),
      tag.meta(name: "twitter:title", content: title),
      tag.meta(name: "twitter:description", content: description),
      tag.meta(name: "twitter:image", content: image)
    ], "\n")
  end

  def og_image_url_for(attachment)
    return nil unless attachment.attached?

    rails_storage_proxy_url(attachment.variant(resize_to_limit: [1200, 1200]))
  end
end
