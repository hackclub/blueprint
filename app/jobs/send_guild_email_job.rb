class SendGuildEmailJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(signup_id)
    signup = GuildSignup.find_by(id: signup_id)
    return unless signup

    template_id = if signup.organizer?
      ENV["GUILDS_ORGANIZER_TEMPLATE_ID"]
    else
      ENV["GUILDS_ATTENDEE_TEMPLATE_ID"]
    end

    if template_id.blank?
      Rails.logger.warn "No Loops template ID configured for #{signup.role} guild emails, skipping"
      return
    end

    response = Faraday.post("https://app.loops.so/api/v1/transactional") do |req|
      req.headers["Authorization"] = "Bearer #{ENV['LOOPS_API_KEY']}"
      req.headers["Content-Type"] = "application/json"
      req.body = {
        transactionalId: template_id,
        email: signup.email,
        dataVariables: {
          name: signup.name,
          city: signup.guild.city,
          role: signup.role
        }
      }.to_json
    end

    unless response.success?
      raise "Loops transactional email failed for signup #{signup_id}: #{response.status} #{response.body}"
    end
  end
end
