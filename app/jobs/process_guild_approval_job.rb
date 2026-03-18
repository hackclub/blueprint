class ProcessGuildApprovalJob < ApplicationJob
  queue_as :default

  def perform(guild_id)
    guild = Guild.find_by(id: guild_id)
    return unless guild

    # Process organizers first, then attendees, to avoid race conditions
    signups = guild.guild_signups.order(
      Arel.sql("CASE WHEN role = 0 THEN 0 ELSE 1 END"), :created_at
    )

    signups.each do |signup|
      ProcessGuildSignupJob.perform_now(signup.id)
    rescue => e
      Rails.logger.error "ProcessGuildApprovalJob: failed to process signup #{signup.id} for guild #{guild_id}: #{e.message}"
    end
  end
end
