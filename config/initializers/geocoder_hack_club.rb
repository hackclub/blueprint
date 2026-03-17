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

    # Address geocoding
    class HackClubGeocode < Base
      def name
        "HackClubGeocode"
      end

      def required_api_key?
        true
      end

      private

      def base_query_url(_query)
        "https://geocoder.hackclub.com/v1/geocode?"
      end

      def query_url(query)
        "#{base_query_url(query)}address=#{ERB::Util.url_encode(query.sanitized_text)}&key=#{configuration.api_key}"
      end

      def results(query)
        return [] if query.ip_address?

        data = fetch_data(query)
        return [] if data.nil? || data == {} || data["error"]
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

    class HackClubGeocode < Base
      def latitude     = @data["lat"]
      def longitude    = @data["lng"]
      def coordinates  = [ latitude, longitude ]

      def city
        raw = @data["raw_backend_response"]
        if raw && raw["results"]
          component = raw["results"].first&.dig("address_components")&.find { |c| c["types"]&.include?("locality") }
          return component["long_name"] if component
        end
        @data["formatted_address"]&.split(",")&.first&.strip
      end

      def state        = @data["state_name"]
      def state_code   = @data["state_code"]
      def country      = @data["country_name"]
      def country_code = @data["country_code"]
      def postal_code  = @data["postal_code"] || @data.dig("raw_backend_response", "results", 0, "address_components")&.find { |c| c["types"]&.include?("postal_code") }&.dig("long_name")

      def formatted_address = @data["formatted_address"]
    end
  end

  # Add :hack_club to the list of available IP services
  Lookup.instance_variable_set(:@ip_services, Lookup.ip_services + [ :hack_club ])

  Lookup.instance_variable_set(:@all_services, Lookup.all_services + [ :hack_club_geocode ]) unless Lookup.all_services.include?(:hack_club_geocode)
  Lookup.instance_variable_set(:@street_services, Lookup.street_services + [ :hack_club_geocode ]) unless Lookup.street_services.include?(:hack_club_geocode)
end
