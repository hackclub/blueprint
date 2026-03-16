# == Schema Information
#
# Table name: guild_airtable_syncs
#
#  id                     :bigint           not null, primary key
#  last_synced_at         :datetime
#  record_identifier      :string
#  synced_attributes_hash :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  airtable_id            :string
#
# Indexes
#
#  index_guild_airtable_syncs_on_record_identifier  (record_identifier) UNIQUE
#
class GuildAirtableSync < ApplicationRecord
  validates :record_identifier, presence: true, uniqueness: true

  def self.sync!(classname, sync_all: true, limit: nil)
    klass = classname.constantize
    records = sync_all ? klass.all : klass.where.not(updated_at: nil)
    sync_records!(klass, records)
  end

  def self.sync_records!(klass, records)
    table_id = klass.airtable_sync_table_id
    mappings = klass.airtable_sync_field_mappings

    if table_id.blank? || ENV["AIRTABLE_GUILDS_BASE_ID"].blank? || ENV["AIRTABLE_API_KEY"].blank?
      Rails.logger.warn "Airtable sync skipped for #{klass.name}: missing configuration"
      return
    end

    records.each do |record|
      existing_sync = find_by(record_identifier: record_identifier(record))
      airtable_id = existing_sync&.airtable_id
      fields = build_airtable_fields(record, mappings)
      new_id = upload_or_create!(table_id, fields, airtable_id)
      upsert_sync_state(record, new_id) if new_id.present?
    end
  end

  def self.upload_or_create!(table_id, fields, existing_id = nil)
    if existing_id
      response = Faraday.patch("https://api.airtable.com/v0/#{ENV['AIRTABLE_GUILDS_BASE_ID']}/#{table_id}/#{existing_id}") do |req|
        req.headers = { "Authorization" => "Bearer #{ENV['AIRTABLE_API_KEY']}", "Content-Type" => "application/json" }
        req.body = { fields: fields, typecast: true }.to_json
      end
    else
      response = Faraday.post("https://api.airtable.com/v0/#{ENV['AIRTABLE_GUILDS_BASE_ID']}/#{table_id}") do |req|
        req.headers = { "Authorization" => "Bearer #{ENV['AIRTABLE_API_KEY']}", "Content-Type" => "application/json" }
        req.body = { fields: fields, typecast: true }.to_json
      end
    end

    unless response.success?
      raise "Airtable sync failed (#{response.status}): #{response.body}"
    end

    JSON.parse(response.body)["id"]
  end

  def self.build_airtable_fields(record, mappings)
    mappings.transform_values do |mapping|
      if mapping.is_a?(Proc)
        mapping.call(record)
      else
        record.send(mapping)
      end
    end
  end

  def self.record_identifier(record)
    "#{record.class.name}##{record.id}"
  end

  def self.delete_record!(klass, record_id)
    table_id = klass.airtable_sync_table_id

    if table_id.blank? || ENV["AIRTABLE_GUILDS_BASE_ID"].blank? || ENV["AIRTABLE_API_KEY"].blank?
      Rails.logger.warn "Airtable delete skipped for #{klass.name}##{record_id}: missing configuration"
      return
    end

    identifier = "#{klass.name}##{record_id}"
    sync = find_by(record_identifier: identifier)
    return unless sync&.airtable_id.present?

    response = Faraday.delete("https://api.airtable.com/v0/#{ENV['AIRTABLE_GUILDS_BASE_ID']}/#{table_id}/#{sync.airtable_id}") do |req|
      req.headers = { "Authorization" => "Bearer #{ENV['AIRTABLE_API_KEY']}" }
    end

    unless response.success?
      raise "Airtable delete failed (#{response.status}): #{response.body}"
    end

    sync.destroy!
  end

  def self.upsert_sync_state(record, airtable_id)
    find_or_initialize_by(record_identifier: record_identifier(record)).tap do |sync|
      sync.airtable_id = airtable_id
      sync.last_synced_at = Time.current
      sync.save!
    end
  end
end
