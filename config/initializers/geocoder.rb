Geocoder.configure(
  timeout: 2,
  ip_lookup: :hack_club,
  hack_club: {
    api_key: ENV["GEOCODER_API_KEY"]
  }
)
