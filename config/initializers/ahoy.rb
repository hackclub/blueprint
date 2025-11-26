class Ahoy::Store < Ahoy::DatabaseStore
  def track_visit(data)
    data[:ip] = request.headers["CF-Connecting-IP"] || request.remote_ip

    if request.session[:user_id] == 1
      begin
        Sentry.capture_message("Ahoy Headers for User 1", extra: { headers: request.headers.to_h })
      rescue => e
        Sentry.capture_exception(e)
      end
    end

    super(data)
  end
end

# set to true for JavaScript tracking
Ahoy.api = false

# set to true for geocoding (and add the geocoder gem to your Gemfile)
# we recommend configuring local geocoding as well
# see https://github.com/ankane/ahoy#geocoding
Ahoy.geocode = true
