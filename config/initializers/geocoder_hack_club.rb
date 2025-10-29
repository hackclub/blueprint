require "geocoder/lookups/base"
require "geocoder/results/base"

module Geocoder
  module Lookup
    class HackClub < Base
      def name
        "HackClub"
      end

      def required_api_key?
        true
      end

      private

      def base_query_url(_query)
        "https://geocoder.hackclub.com/v1/geoip?"
      end

      def query_url(query)
        "#{base_query_url(query)}ip=#{query.sanitized_text}&key=#{configuration.api_key}"
      end

      def results(query)
        return [] unless query.ip_address?

        data = fetch_data(query)
        return [] if data.nil? || data == {}
        [ data ]
      end

      def supported_protocols
        [ :http, :https ]
      end

      def fetch_raw_data(query)
        url = query_url(query)
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")

        request = Net::HTTP::Get.new(uri.request_uri)
        response = http.request(request)

        response.body
      end

      def parse_raw_data(raw_data)
        JSON.parse(raw_data)
      rescue JSON::ParserError
        {}
      end
    end
  end

  module Result
    class HackClub < Base
      def latitude     = @data["lat"]
      def longitude    = @data["lng"]
      def coordinates  = [ latitude, longitude ]

      def city         = @data["city"]
      def state        = @data["region"]
      def state_code   = nil
      def country      = @data["country_name"]
      def country_code = @data["country_code"]
      def postal_code  = @data["postal_code"]

      def ip           = @data["ip"]
      def timezone     = @data["timezone"]
      def organization = @data["org"]
    end
  end

  # Add :hack_club to the list of available IP services
  Lookup.instance_variable_set(:@ip_services, Lookup.ip_services + [ :hack_club ])
end
