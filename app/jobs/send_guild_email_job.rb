class SendGuildEmailJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(signup_id)
    signup = GuildSignup.find_by(id: signup_id)
    return unless signup

    return if signup.volunteer?

    template_id = if signup.organizer?
      ENV["GUILDS_ORGANIZER_TEMPLATE_ID"]
    else
      ENV["GUILDS_ATTENDEE_TEMPLATE_ID"]
    end

    return if template_id.blank?

    response = Faraday.post("https://app.loops.so/api/v1/transactional") do |req|
      req.headers["Authorization"] = "Bearer #{ENV['LOOPS_API_KEY']}"
      req.headers["Content-Type"] = "application/json"
      guild = signup.guild

      req.body = {
        transactionalId: template_id,
        email: signup.email,
        dataVariables: {
          name: signup.name,
          city: guild.city,
          "city-slack": guild.city.parameterize
        }
      }.to_json
    end

    unless response.success?
      raise "Loops transactional email failed for signup #{signup_id}: #{response.status} #{response.body}"
    end
  end
end
