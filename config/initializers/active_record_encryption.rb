# frozen_string_literal: true

# Active Record Encryption configuration
# Generate keys with: bin/rails db:encryption:init
# Then add to credentials with: bin/rails credentials:edit
#
# active_record_encryption:
#   primary_key: <generated>
#   deterministic_key: <generated>
#   key_derivation_salt: <generated>

if Rails.application.credentials.active_record_encryption.present?
  config = Rails.application.credentials.active_record_encryption
  Rails.application.config.active_record.encryption.primary_key = config[:primary_key]
  Rails.application.config.active_record.encryption.deterministic_key = config[:deterministic_key]
  Rails.application.config.active_record.encryption.key_derivation_salt = config[:key_derivation_salt]
end
