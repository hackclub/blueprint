class Ahoy::Store < Ahoy::DatabaseStore
  def track_visit(data)
    data[:ip] = request.headers["CF-Connecting-IP"] || request.remote_ip
    super(data)
  end
end

# set to true for JavaScript tracking
Ahoy.api = false

# set to true for geocoding (and add the geocoder gem to your Gemfile)
# we recommend configuring local geocoding as well
# see https://github.com/ankane/ahoy#geocoding
Ahoy.geocode = true
Ahoy.job_queue = :background
