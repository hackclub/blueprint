class AirtableUrgentSyncUsersJob < ApplicationJob
  queue_as :default

  BATCH_LIMIT = 1000

  def perform
    users = User.where(first_synced_to_airtable: false).order(:id).limit(BATCH_LIMIT).to_a
    return if users.empty?

    AirtableSync.sync_records!(User, users)
  end
end
