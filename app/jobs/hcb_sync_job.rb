class HcbSyncJob < ApplicationJob
  queue_as :default

  def perform(org_id = nil, fast: false)
    org_id ||= HcbScraperService.default_org_id

    sync_grants(org_id, fast: fast)
  end

  private

  def sync_grants(org_id, fast:)
    now = Time.current

    Rails.logger.info "Starting HCB sync for org #{org_id} (fast=#{fast})"

    grant_hashes = HcbScraperService.fetch_grants(org_id, fast: fast)

    Rails.logger.info "Fetched #{grant_hashes.size} grants from HCB"

    existing_grants = HcbGrant.where(
      org_id: org_id,
      grant_id: grant_hashes.map { |g| g[:grant_id] }
    ).index_by(&:grant_id)

    grants_to_insert = []
    grants_to_update = []
    grant_transaction_map = {}

    grant_hashes.each do |grant_hash|
      grant_id = grant_hash[:grant_id]
      existing_grant = existing_grants[grant_id]

      if existing_grant
        attrs = grant_hash.slice(
          :status,
          :initial_amount_cents,
          :balance_cents,
          :to_user_name,
          :to_user_avatar,
          :for_reason,
          :issued_at,
          :source_url
        )

        attrs[:balance_cents] ||= existing_grant.balance_cents
        attrs[:to_user_avatar] ||= existing_grant.to_user_avatar
        attrs[:status] ||= existing_grant.status
        attrs[:initial_amount_cents] ||= existing_grant.initial_amount_cents
        attrs[:to_user_name] ||= existing_grant.to_user_name
        attrs[:for_reason] ||= existing_grant.for_reason
        attrs[:issued_at] ||= existing_grant.issued_at
        attrs[:source_url] ||= existing_grant.source_url

        attrs[:org_id] = grant_hash[:org_id]
        attrs[:grant_id] = grant_id
        attrs[:last_seen_at] = now
        attrs[:last_synced_at] = now
        attrs[:soft_deleted_at] = nil
        attrs[:id] = existing_grant.id
        attrs[:first_seen_at] = existing_grant.first_seen_at
        attrs[:created_at] = existing_grant.created_at
        attrs[:updated_at] = now

        grants_to_update << attrs
        grant_transaction_map[existing_grant.id] = grant_hash[:transactions] || []
      else
        attrs = {
          org_id: grant_hash[:org_id],
          grant_id: grant_id,
          status: grant_hash[:status],
          initial_amount_cents: grant_hash[:initial_amount_cents],
          balance_cents: grant_hash[:balance_cents],
          to_user_name: grant_hash[:to_user_name],
          to_user_avatar: grant_hash[:to_user_avatar],
          for_reason: grant_hash[:for_reason],
          issued_at: grant_hash[:issued_at],
          source_url: grant_hash[:source_url],
          last_seen_at: now,
          last_synced_at: now,
          soft_deleted_at: nil,
          first_seen_at: now,
          created_at: now,
          updated_at: now,
          sync_failures_count: 0
        }

        grants_to_insert << attrs
      end
    rescue StandardError => e
      handle_grant_sync_error(grant_hash, e)
    end

    inserted_grant_ids = []
    if grants_to_insert.any?
      result = HcbGrant.insert_all(
        grants_to_insert,
        returning: [ :id, :grant_id ]
      )
      inserted_grant_ids = result.rows.map { |row| { id: row[0], grant_id: row[1] } }
    end

    if grants_to_update.any?
      HcbGrant.upsert_all(
        grants_to_update,
        unique_by: [ :org_id, :grant_id ]
      )
    end

    inserted_grant_ids.each do |grant_info|
      grant_hash = grant_hashes.find { |g| g[:grant_id] == grant_info[:grant_id] }
      grant_transaction_map[grant_info[:id]] = grant_hash[:transactions] || [] if grant_hash
    end

    sync_all_transactions(grant_transaction_map, org_id, now)

    soft_delete_stale_grants(org_id, now)

    Rails.logger.info "Completed HCB sync for org #{org_id}"
  end

  def sync_all_transactions(grant_transaction_map, org_id, now)
    return if grant_transaction_map.empty?

    grant_ids = grant_transaction_map.keys
    all_tx_hashes = grant_transaction_map.values.flatten

    existing_transactions = HcbTransaction.where(
      hcb_grant_id: grant_ids,
      transaction_id: all_tx_hashes.map { |tx| tx[:transaction_id] }.compact.uniq
    ).index_by { |tx| [ tx.hcb_grant_id, tx.transaction_id ] }

    transactions_to_insert = []
    transactions_to_update = []

    grant_transaction_map.each do |grant_id, tx_hashes|
      tx_hashes.each do |tx_hash|
        next if tx_hash[:transaction_id].blank?

        existing_tx = existing_transactions[[ grant_id, tx_hash[:transaction_id] ]]

        if existing_tx
          attrs = tx_hash.slice(
            :status,
            :amount_cents,
            :receipt_count,
            :memo,
            :hcb_created_at
          )

          attrs[:status] ||= existing_tx.status
          attrs[:amount_cents] ||= existing_tx.amount_cents
          attrs[:receipt_count] ||= existing_tx.receipt_count
          attrs[:memo] ||= existing_tx.memo
          attrs[:hcb_created_at] ||= existing_tx.hcb_created_at

          attrs[:hcb_grant_id] = grant_id
          attrs[:org_id] = org_id
          attrs[:transaction_id] = tx_hash[:transaction_id]
          attrs[:last_seen_at] = now
          attrs[:last_synced_at] = now
          attrs[:id] = existing_tx.id
          attrs[:first_seen_at] = existing_tx.first_seen_at
          attrs[:created_at] = existing_tx.created_at
          attrs[:updated_at] = now

          transactions_to_update << attrs
        else
          attrs = {
            hcb_grant_id: grant_id,
            org_id: org_id,
            transaction_id: tx_hash[:transaction_id],
            status: tx_hash[:status],
            amount_cents: tx_hash[:amount_cents],
            receipt_count: tx_hash[:receipt_count],
            memo: tx_hash[:memo],
            hcb_created_at: tx_hash[:hcb_created_at],
            last_seen_at: now,
            last_synced_at: now,
            first_seen_at: now,
            created_at: now,
            updated_at: now
          }

          transactions_to_insert << attrs
        end
      end
    end

    HcbTransaction.insert_all(transactions_to_insert) if transactions_to_insert.any?
    HcbTransaction.upsert_all(transactions_to_update, unique_by: [ :org_id, :transaction_id ]) if transactions_to_update.any?
  end

  def handle_grant_sync_error(grant_hash, error)
    grant_id = grant_hash[:grant_id]

    Rails.logger.error "Failed to sync grant #{grant_id}: #{error.message}"
    Sentry.capture_exception(error, extra: { grant_id: grant_id })

    grant = HcbGrant.find_by(
      org_id: grant_hash[:org_id],
      grant_id: grant_id
    )

    return unless grant

    grant.increment!(:sync_failures_count)
    grant.update_column(:last_sync_error, "#{error.class}: #{error.message}".truncate(1000))
  end

  def soft_delete_stale_grants(org_id, now)
    stale_threshold = now - 7.days

    HcbGrant.where(org_id: org_id)
      .where("last_seen_at < ?", stale_threshold)
      .where(soft_deleted_at: nil)
      .update_all(soft_deleted_at: now)
  end
end
