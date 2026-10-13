class PrivacyToken
  class Invalid < StandardError; end
  class ActionMismatch < StandardError; end
  class Replayed < StandardError; end
  class Unavailable < StandardError; end

  ISSUER = "hackclub-privacy"
  AUDIENCE = "blueprint"
  ALGORITHM = "ES256"
  LEEWAY = 30
  MAX_LIFETIME = 300
  JWKS_TTL = 5.minutes
  JWKS_REFETCH_INTERVAL = 30.seconds
  REQUIRED_CLAIMS = %w[iss aud iat exp jti request_id action subject].freeze

  JWKS_LOCK = Mutex.new

  class << self
    def verify!(token, action:)
      payload, header = decode(token)

      raise Invalid unless header["typ"] == "JWT"
      raise Invalid unless valid_lifetime?(payload)
      raise Invalid unless payload["subject"].is_a?(Hash)
      raise ActionMismatch unless payload["action"] == action
      raise Replayed unless PrivacyTokenUse.first_use?(payload["jti"].to_s)

      payload
    end

    private

    def decode(token)
      raise Invalid if token.blank?

      JWT.decode(
        token, nil, true,
        algorithms: [ ALGORITHM ],
        jwks: method(:jwks),
        iss: ISSUER,
        verify_iss: true,
        aud: AUDIENCE,
        verify_aud: true,
        leeway: LEEWAY,
        required_claims: REQUIRED_CLAIMS
      )
    rescue JWT::DecodeError
      raise Invalid
    end

    def valid_lifetime?(payload)
      iat = payload["iat"]
      exp = payload["exp"]
      return false unless iat.is_a?(Numeric) && exp.is_a?(Numeric)

      now = Time.current.to_i
      iat <= now + LEEWAY && iat >= now - MAX_LIFETIME - LEEWAY && exp - iat <= MAX_LIFETIME
    end

    def jwks(options = {})
      JWKS_LOCK.synchronize do
        max_age = options[:kid_not_found] ? JWKS_REFETCH_INTERVAL : JWKS_TTL
        if @jwks.nil? || @jwks_fetched_at < max_age.ago
          @jwks = fetch_jwks
          @jwks_fetched_at = Time.current
        end
        @jwks
      end
    end

    def fetch_jwks
      response = Faraday.get(jwks_url) do |req|
        req.options.open_timeout = 3
        req.options.timeout = 5
      end
      raise Unavailable unless response.success?

      JSON.parse(response.body)
    rescue Faraday::Error, JSON::ParserError
      raise Unavailable
    end

    def jwks_url
      ENV["PRIVACY_JWKS_URL"].presence || "https://yeet.hackclub.com/.well-known/jwks.json"
    end
  end
end
