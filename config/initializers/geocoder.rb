if defined?(Geocoder::Request::GEOCODER_CANDIDATE_HEADERS)
  Geocoder::Request::GEOCODER_CANDIDATE_HEADERS.unshift(
    "HTTP_CF_CONNECTING_IP",
    "HTTP_TRUE_CLIENT_IP"
  )
end

Geocoder.configure(
  timeout: 2,
  ip_lookup: :hack_club,
  hack_club: {
    api_key: ENV["GEOCODER_API_KEY"]
  }
)
