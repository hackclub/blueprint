module AiReviewer
  module GithubClient
    GH_PROXY_BASE = "https://gh-proxy.hackclub.com/gh".freeze

    private

    def github_fetch(path)
      api_key = ENV.fetch("GH_PROXY_API_KEY", "")
      conn = Faraday.new do |f|
        f.options.open_timeout = 10
        f.options.timeout = 30
      end
      conn.get("#{GH_PROXY_BASE}#{path}", nil, {
        "X-API-Key" => api_key,
        "Accept" => "application/vnd.github+json"
      })
    end
  end
end
