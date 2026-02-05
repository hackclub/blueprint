# frozen_string_literal: true

class HcbOauthService
  class << self
    def host
      @host ||= ENV.fetch("HCB_OAUTH_HOST", "https://hcb.hackclub.com").chomp("/")
    end

    def authorize_url(redirect_uri, state:)
      ensure_https_redirect!(redirect_uri)

      params = {
        client_id: ENV.fetch("HCB_CLIENT_ID"),
        redirect_uri:,
        response_type: "code",
        scope: "read write",
        state:
      }.compact_blank

      "#{host}/api/v4/oauth/authorize?#{params.to_query}"
    end

    def exchange_token(redirect_uri, code)
      ensure_https_redirect!(redirect_uri)

      can_retry do
        conn.post("/api/v4/oauth/token") do |req|
          req.headers["Content-Type"] = "application/x-www-form-urlencoded"
          req.body = URI.encode_www_form({
            client_id: ENV.fetch("HCB_CLIENT_ID"),
            client_secret: ENV.fetch("HCB_CLIENT_SECRET"),
            redirect_uri:,
            code:,
            grant_type: "authorization_code"
          })
        end.body
      end
    end

    def refresh_token(refresh_token)
      raise ArgumentError, "refresh_token is required" unless refresh_token.present?

      can_retry do
        conn.post("/api/v4/oauth/token") do |req|
          req.headers["Content-Type"] = "application/x-www-form-urlencoded"
          req.body = URI.encode_www_form({
            client_id: ENV.fetch("HCB_CLIENT_ID"),
            client_secret: ENV.fetch("HCB_CLIENT_SECRET"),
            refresh_token:,
            grant_type: "refresh_token"
          })
        end.body
      end
    end

    # TODO: Add API methods here as needed
    # Example:
    # def me(access_token)
    #   raise ArgumentError, "access_token is required" unless access_token.present?
    #   can_retry do
    #     conn.get("/api/v4/me", nil, { Authorization: "Bearer #{access_token}" }).body
    #   end
    # end

    private

    def ensure_https_redirect!(redirect_uri)
      uri = URI.parse(redirect_uri)
      return if Rails.env.development? && %w[http https].include?(uri.scheme)
      return if uri.scheme == "https"

      raise ArgumentError, "redirect_uri must use HTTPS"
    end

    def can_retry(max = 3)
      retries = 0
      begin
        yield
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError, SocketError => e
        retries += 1
        if retries <= max
          Rails.logger.warn "HCB OAuth request failed (try #{retries}/#{max + 1}): #{e.message}"
          sleep(0.5 * retries)
          retry
        else
          Rails.logger.error "HCB OAuth request failed after retry: #{e.message}"
          Sentry.capture_exception(e)
          raise
        end
      end
    end

    def conn
      @conn ||= Faraday.new(
        url: host,
        request: { timeout: 10, open_timeout: 5 }
      ) do |f|
        f.request :json
        f.response :json, parser_options: { symbolize_names: true }
        f.response :raise_error
      end
    end
  end
end
