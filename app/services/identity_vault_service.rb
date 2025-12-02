# frozen_string_literal: true

class IdentityVaultService
  class << self
    def env
      Rails.env.production? ? :prod : :staging
    end

    def host
      @host ||= {
        staging: "https://hca.dinosaurbbq.org/",
        prod: "https://auth.hackclub.com/"
      }[env]
    end

    def authorize_url(redirect_uri, sneaky_params = nil, state: nil)
      params = {
        client_id: ENV["IDENTITY_VAULT_CLIENT_ID"],
        redirect_uri:,
        response_type: "code",
        scope: "basic_info address",
        state:,
        stash_data: encode_sneaky_params(sneaky_params)
      }.compact_blank

      "#{host}oauth/authorize?#{params.to_query}"
    end

    def exchange_token(redirect_uri, code)
      can_retry do
        begin
          conn.post("/oauth/token") do |req|
            req.headers["Content-Type"] = "application/x-www-form-urlencoded"
            req.body = URI.encode_www_form({
              client_id: ENV["IDENTITY_VAULT_CLIENT_ID"],
              client_secret: ENV["IDENTITY_VAULT_CLIENT_SECRET"],
              redirect_uri:,
              code:,
              grant_type: "authorization_code"
            })
          end.body
        rescue Faraday::BadRequestError => e
          Sentry.capture_exception(e, extra: { response_body: e.response })
          raise e
        end
      end
    end

    def me(user_token)
      raise ArgumentError, "user_token is required" unless user_token

      can_retry do
        conn.get("/api/v1/me", nil, {
                   Authorization: "Bearer #{user_token}"
                 }).body
      end
    end

    def get_identity(identity_id)
      can_retry do
        conn.get("/api/v1/identities/#{identity_id}").body
      end
    end

    def set_slack_id(identity_id, slack_id)
      can_retry do
        conn.post("api/v1/identities/#{identity_id}/set_slack_id", { slack_id: }).body
      end
    end

    def build_address_creation_url(sneaky_params = nil)
      params = {
        stash_data: encode_sneaky_params(sneaky_params)
      }.compact_blank

      "#{host}addresses/program_create_address?#{params.to_query}"
    end

    private

    def can_retry(max = 3)
      retries = 0
      begin
        yield
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError, SocketError => e
        retries += 1
        if retries <= max
          Rails.logger.warn "idv poll failed (try #{retries}/#{max + 1}): #{e.message}"
          sleep(0.5 * retries)
          retry
        else
          Rails.logger.error "idv poll failed after retry: #{e.message}"
          Sentry.capture_exception(e)
          raise
        end
      end
    end

    def conn
      @conn ||= Faraday.new(
        url: host,
        headers: {
          "Authorization" => "Bearer #{ENV['IDENTITY_VAULT_GLOBAL_PROGRAM_KEY']}"
        }
      ) do |f|
        f.request :json
        f.response :json, parser_options: { symbolize_names: true }
        f.response :raise_error
      end
    end

    def encode_sneaky_params(params)
      return nil unless params

      Base64.urlsafe_encode64(LZString::UTF16.compress(params.to_json))
    end
  end
end
