class GuildSyncAirtableJob < ApplicationJob
  queue_as :background

  def perform(response_url)
    guild_count = Guild.count
    signup_count = GuildSignup.count
    results = []

    Rails.logger.info "[GuildSyncAirtable] Starting sync: #{guild_count} guilds, #{signup_count} signups"

    begin
      Rails.logger.info "[GuildSyncAirtable] Syncing guilds..."
      AirtableSync.sync!("Guild", sync_all: true, cleanup: true)
      Rails.logger.info "[GuildSyncAirtable] Guilds synced successfully"
      results << "Guilds: #{guild_count} synced"
    rescue => e
      Rails.logger.error "[GuildSyncAirtable] Guild sync failed: #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
      results << "Guilds: failed (#{e.message})"
    end

    guilds_with_airtable_id = AirtableSync.where("record_identifier LIKE 'Guild#%'").where.not(airtable_id: [ nil, "" ]).count
    Rails.logger.info "[GuildSyncAirtable] Guilds with record id in airtable: #{guilds_with_airtable_id}/#{guild_count}"

    begin
      Rails.logger.info "[GuildSyncAirtable] Syncing signups..."
      failed_signups = sync_signups_individually!
      if failed_signups.empty?
        Rails.logger.info "[GuildSyncAirtable] Signups synced successfully"
        results << "Signups: #{signup_count} synced (#{guilds_with_airtable_id}/#{guild_count} guilds linkable)"
      else
        Rails.logger.warn "[GuildSyncAirtable] #{failed_signups.size}/#{signup_count} signups failed"
        results << "Signups: #{signup_count - failed_signups.size}/#{signup_count} synced, #{failed_signups.size} failed (#{guilds_with_airtable_id}/#{guild_count} guilds linkable)"
      end
    rescue => e
      Rails.logger.error "[GuildSyncAirtable] Signup sync failed: #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
      results << "Signups: failed (#{e.message})"
    end

    summary = results.join("\n")
    Rails.logger.info "[GuildSyncAirtable] Done. #{summary}"
    post_to_response_url(response_url, "Sync complete.\n#{summary}")
  rescue => e
    Rails.logger.error "[GuildSyncAirtable] Job failed: #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
    post_to_response_url(response_url, "Sync failed: #{e.message}") if response_url.present?
    raise
  end

  private

  def sync_signups_individually!
    signups = GuildSignup.all.to_a
    mappings = GuildSignup.airtable_sync_field_mappings
    base_id = GuildSignup.airtable_sync_base_id
    table_id = GuildSignup.airtable_sync_table_id
    failed = []

    signups.each_with_index do |signup, index|
      if (index + 1) % 100 == 0 || index + 1 == signups.size
        Rails.logger.info "[GuildSyncAirtable] Processing GuildSignup (#{index + 1}/#{signups.size})"
      end
      begin
        airtable_id = AirtableSync.individual_sync!(table_id, signup, mappings, nil, base_id: base_id)
        AirtableSync.mark_synced(signup, airtable_id)
      rescue => e
        fields = AirtableSync.send(:build_airtable_fields, signup, mappings)
        Rails.logger.error "[GuildSyncAirtable] Failed GuildSignup##{signup.id} (guild_id=#{signup.guild_id}): #{e.message}. Fields: #{fields.inspect}"
        failed << signup
      end
    end

    AirtableSync.send(:cleanup_deleted_records!, GuildSignup, signups,
      base_id: base_id, table_id: table_id, log_prefix: "[GuildSyncAirtable]")

    failed
  end

  def post_to_response_url(response_url, text)
    return unless response_url.present?

    uri = URI.parse(response_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
    request.body = { response_type: "in_channel", text: text }.to_json
    http.request(request)
  rescue => e
    Rails.logger.error "[GuildSyncAirtable] Failed to post result to response_url: #{e.message}"
  end
end
