module AiReviewer
  module GithubClient
    GH_PROXY_BASE = "https://gh-proxy.hackclub.com/gh".freeze

    private

    def github_fetch(path)
      api_key = ENV.fetch("GH_PROXY_API_KEY", "")
      Faraday.get("#{GH_PROXY_BASE}#{path}", nil, {
        "X-API-Key" => api_key,
        "Accept" => "application/vnd.github+json"
      })
    end
  end
end
