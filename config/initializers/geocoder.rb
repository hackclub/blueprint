if defined?(Geocoder::Request::GEOCODER_CANDIDATE_HEADERS)
  Geocoder::Request::GEOCODER_CANDIDATE_HEADERS.unshift(
    "HTTP_CF_CONNECTING_IP",
    "HTTP_TRUE_CLIENT_IP"
  )
end

Geocoder.configure(
  timeout: 5,
  units: :mi,
  ip_lookup: :hack_club,
  hack_club: {
    api_key: ENV["GEOCODER_API_KEY"]
  },
  lookup: :hack_club_geocode,
  hack_club_geocode: {
    api_key: ENV["GEOCODER_API_KEY"]
  },
  use_https: true
)
