module GuildSignupProtection
  BLOCKLIST_URL = "https://raw.githubusercontent.com/disposable-email-domains/disposable-email-domains/master/disposable_email_blocklist.conf".freeze
  CACHE_KEY = "disposable_email_domains_set".freeze
  CACHE_TTL = 24.hours

  EXTRA_DOMAINS = %w[
    tempmail.ing aniimate.net animateany.com gettranslation.app deepask.app
    animatimg.com theeditai.com wnbaldwy.com marvetos.com
  ].freeze # domains we have seen and are explicitly blocking

  def self.disposable_domain?(domain)
    blocked_domains.include?(domain)
  end

  def self.blocked_domains
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { fetch_blocklist }
  end

  def self.fetch_blocklist
    require "net/http"
    uri = URI(BLOCKLIST_URL)
    response = Net::HTTP.get_response(uri)
    raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    domains = response.body.each_line.map { |line| line.strip.downcase }.reject(&:blank?)
    Set.new(domains + EXTRA_DOMAINS)
  rescue => e
    Rails.logger.error "Failed to fetch disposable email blocklist: #{e.message}"
    Rails.cache.read(CACHE_KEY) || Set.new(EXTRA_DOMAINS)
  end
end
