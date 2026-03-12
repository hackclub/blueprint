class SlackCommandsController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!, only: [ :handle ]
  before_action :verify_slack_request

  def handle
    case params[:command]
    when "/guild-stats"
      render json: { response_type: "ephemeral", text: guild_stats_message }
    when "/guild-no-organizers"
      render json: { response_type: "ephemeral", text: guilds_without_organizers_message }
    when "/guild-top"
      limit = parse_limit(params[:text])
      render json: { response_type: "ephemeral", text: guilds_top_message(limit) }
    else
      render json: { response_type: "ephemeral", text: "Unknown command." }
    end
  end

  private

  def parse_limit(input)
    input.to_i > 0 ? input.to_i : 10
  end

  def guild_stats_message
    total_guilds = Guild.count
    total_organizers = GuildSignup.where(role: :organizer).count
    total_attendees = GuildSignup.where(role: :attendee).count
    total_signups = GuildSignup.count

    <<~MSG
      *Guild Stats*
      • Total guilds: #{total_guilds}
      • Total organizers: #{total_organizers}
      • Total attendees: #{total_attendees}
      • Total signups: #{total_signups}
    MSG
  end

  def guilds_without_organizers_message
    guilds = Guild.left_joins(:guild_signups)
                  .where(guild_signups: { id: nil })
                  .or(Guild.where.not(id: Guild.joins(:guild_signups).where(guild_signups: { role: :organizer }).select(:id)))
    count = guilds.count
    list = guilds.pluck(:name).map { |name| "• #{name}" }.join("\n")

    if count > 0
      "There #{count == 1 ? 'is' : 'are'} #{count} guild #{count == 1 ? '' : 's'} with no organizers:\n#{list}"
    else
      "All guilds have at least one organizer!"
    end
  end

  def guilds_top_message(limit)
    guilds = Guild.left_joins(:guild_signups)
                  .select("guilds.*, COUNT(guild_signups.id) as signups_count")
                  .group("guilds.id")
                  .order("signups_count DESC")
                  .limit(limit)

    if guilds.any?
      list = guilds.map.with_index(1) do |g, i|
        "#{i}. #{g.name} – #{g.signups_count} signup#{'s' unless g.signups_count == 1}"
      end.join("\n")
      "Top #{limit} guild#{'s' unless limit == 1} by total signups:\n#{list}"
    else
      "No guilds found."
    end
  end


  def verify_slack_request
    return true if Rails.env.development?

    signing_secret = ENV["SLACK_SIGNING_SECRET"]
    slack_signature = request.headers["X-Slack-Signature"]
    slack_timestamp = request.headers["X-Slack-Request-Timestamp"]

    if Time.at(slack_timestamp.to_i) < 5.minutes.ago
      head :unauthorized and return
    end

    sig_basestring = "v0:#{slack_timestamp}:#{request.raw_post}"
    computed_signature = "v0=" + OpenSSL::HMAC.hexdigest("SHA256", signing_secret, sig_basestring)

    unless ActiveSupport::SecurityUtils.secure_compare(computed_signature, slack_signature)
      head :unauthorized and return
    end
  end
end
