class Ahoy::Store < Ahoy::DatabaseStore
  def visit_properties
    begin
      Sentry.capture_message("Ahoy Headers", extra: { headers: request.headers.to_h })
    rescue => e
      Sentry.capture_exception(e)
    end

    super.merge(
      ip: request.headers["CF-Connecting-IP"] || request.remote_ip
    )
  end
end

# set to true for JavaScript tracking
Ahoy.api = false

# set to true for geocoding (and add the geocoder gem to your Gemfile)
# we recommend configuring local geocoding as well
# see https://github.com/ankane/ahoy#geocoding
Ahoy.geocode = true
