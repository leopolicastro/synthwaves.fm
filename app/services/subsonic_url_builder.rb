class SubsonicUrlBuilder
  def initialize(user, base_url:)
    @user = user
    @base_url = base_url
  end

  def stream_url(track)
    build_url("/rest/stream", id: track.id)
  end

  def cover_art_url(album, size: 300)
    build_url("/rest/getCoverArt", id: album.id, size: size)
  end

  private

  def build_url(path, **extra_params)
    salt = SecureRandom.hex(12)
    token = Digest::MD5.hexdigest("#{@user.subsonic_password}#{salt}")

    params = {
      u: @user.email_address,
      t: token,
      s: salt,
      v: SubsonicResponseFormatting::SUBSONIC_API_VERSION,
      c: "synthwaves-ios",
      f: "json"
    }.merge(extra_params)

    "#{@base_url}#{path}?#{params.to_query}"
  end
end
