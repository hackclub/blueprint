class Rack::Attack
  # Throttle POST /auth/email by IP (5 requests per minute)
  throttle("auth/email/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/auth/email") && req.post?
  end

  # Throttle POST /auth/email by email parameter (3 requests per minute)
  throttle("auth/email/email", limit: 3, period: 1.minute) do |req|
    if req.path.start_with?("/auth/email") && req.post?
      req.params["email"].to_s.strip.downcase.presence
    end
  end

  # Throttle POST /auth/track by IP (10 requests per minute)
  throttle("auth/track/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path == "/auth/track" && req.post?
  end

  # Throttle OAuth callbacks by IP (20 requests per minute)
  throttle("oauth/slack/callback/ip", limit: 20, period: 1.minute) do |req|
    req.ip if req.path == "/auth/slack/callback" && req.get?
  end

  throttle("oauth/github/callback/ip", limit: 20, period: 1.minute) do |req|
    req.ip if req.path == "/auth/github/callback" && req.get?
  end

  throttle("oauth/idv/callback/ip", limit: 20, period: 1.minute) do |req|
    req.ip if req.path == "/idv_callback" && req.get?
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |env|
    [
      429,
      { "Content-Type" => "text/plain" },
      [ "Rate limit exceeded. Please try again later.\n" ]
    ]
  end
end
