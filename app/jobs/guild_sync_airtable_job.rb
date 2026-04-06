class GuildSyncAirtableJob < ApplicationJob
  queue_as :background

  def perform(response_url)
    guild_count = Guild.count
    signup_count = GuildSignup.count
    results = []

    begin
      AirtableSync.sync!("Guild", sync_all: true, cleanup: true)
      results << "Guilds: #{guild_count} synced"
    rescue => e
      results << "Guilds: failed (#{e.message})"
    end

    guilds_with_airtable_id = AirtableSync.where("record_identifier LIKE 'Guild#%'").where.not(airtable_id: [ nil, "" ]).count

    begin
      failed_signups = sync_signups_individually!
      if failed_signups.empty?
        results << "Signups: #{signup_count} synced (#{guilds_with_airtable_id}/#{guild_count} guilds linkable)"
      else
        failure_details = failed_signups.map { |f| "• GuildSignup##{f[:signup].id} (guild_id=#{f[:signup].guild_id}): #{f[:error]}" }.join("\n")
        results << "Signups: #{signup_count - failed_signups.size}/#{signup_count} synced, #{failed_signups.size} failed (#{guilds_with_airtable_id}/#{guild_count} guilds linkable)\n#{failure_details}"
      end
    rescue => e
      results << "Signups: failed (#{e.message})"
    end

    summary = results.join("\n")
    post_to_response_url(response_url, "Sync complete.\n#{summary}")
  rescue => e
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

    signups.each do |signup|
      begin
        airtable_id = AirtableSync.individual_sync!(table_id, signup, mappings, nil, base_id: base_id)
        AirtableSync.mark_synced(signup, airtable_id)
      rescue => e
        failed << { signup: signup, error: e.message }
      end
    end

    AirtableSync.send(:cleanup_deleted_records!, GuildSignup, signups,
      base_id: base_id, table_id: table_id, log_prefix: "GuildSyncAirtable")

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
  rescue
  end
end
