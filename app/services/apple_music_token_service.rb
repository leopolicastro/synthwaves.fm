class AppleMusicTokenService
  ALGORITHM = "ES256"
  TOKEN_LIFETIME = 6.months
  CACHE_KEY = "apple_music_developer_token"

  class Error < StandardError; end

  def self.token
    Rails.cache.fetch(CACHE_KEY, expires_in: TOKEN_LIFETIME - 1.hour) do
      generate_token
    end
  end

  def self.configured?
    credentials.present? &&
      credentials[:team_id].present? &&
      credentials[:key_id].present? &&
      credentials[:private_key].present?
  end

  def self.generate_token
    raise Error, "Apple Music credentials not configured" unless configured?

    payload = {
      iss: credentials[:team_id],
      iat: Time.now.to_i,
      exp: TOKEN_LIFETIME.from_now.to_i
    }

    private_key = OpenSSL::PKey::EC.new(credentials[:private_key])
    JWT.encode(payload, private_key, ALGORITHM, kid: credentials[:key_id])
  end

  def self.credentials
    Rails.application.credentials.apple_music
  end

  private_class_method :generate_token, :credentials
end
