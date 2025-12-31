namespace :images do
  desc "Delete all existing image variants"
  task delete_variants: :environment do
    count = ActiveStorage::VariantRecord.count
    ActiveStorage::VariantRecord.delete_all
    puts "Deleted #{count} variant records. Orphaned files in storage can be cleaned up separately."
  end

  desc "Pre-process web variants for demo_pictures and journal images"
  task preprocess_variants: :environment do
    require "parallel"

    if ENV["SKIP_SSL_VERIFY"] && Rails.env.development?
      puts "WARNING: Disabling SSL verification for development only"
      OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
    end

    variant_options = { resize_to_limit: [ 2000, 2000 ], convert: :webp, saver: { quality: 80, strip: true } }
    threads = ENV.fetch("THREADS", 8).to_i
    processed = Concurrent::AtomicFixnum.new(0)
    failed = Concurrent::AtomicFixnum.new(0)

    puts "Using #{threads} parallel threads..."

    # Collect all image blob IDs (includes demo_pictures and journal images)
    puts "\nCollecting image blobs..."
    image_blob_ids = ActiveStorage::Blob
      .joins(:attachments)
      .where("content_type LIKE 'image/%'")
      .where.not(active_storage_attachments: { record_type: "ActiveStorage::VariantRecord" })
      .left_joins(:variant_records)
      .where(active_storage_variant_records: { id: nil })
      .distinct
      .pluck(:id)
    puts "Found #{image_blob_ids.count} image blobs to process"

    Parallel.each(image_blob_ids, in_threads: threads) do |blob_id|
      blob = ActiveStorage::Blob.find(blob_id)
      next unless blob.image?

      blob.variant(variant_options).processed
      processed.increment
      puts "Processed Blob##{blob_id} (#{blob.filename})"
    rescue => e
      failed.increment
      puts "Failed for Blob##{blob_id}: #{e.message}"
    end

    puts "\n\nDone! Processed: #{processed.value}, Failed: #{failed.value}"
  end
end
