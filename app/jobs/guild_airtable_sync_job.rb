class GuildAirtableSyncJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(guild_id)
    guild = Guild.find_by(id: guild_id)
    return unless guild

    GuildAirtableSync.sync_records!(Guild, [ guild ])
  end
end
