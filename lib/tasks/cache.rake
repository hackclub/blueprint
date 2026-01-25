namespace :cache do
  desc "Warm markdown cache (with lock to prevent duplicates)"
  task warm_markdown: :environment do
    lock_key = "warm_markdown_cache_lock"
    lock_ttl = 5.minutes

    if Rails.cache.write(lock_key, Time.current.to_s, unless_exist: true, expires_in: lock_ttl)
      begin
        WarmMarkdownCacheJob.perform_later
        puts "Queued WarmMarkdownCacheJob"
      rescue => e
        Sentry.capture_exception("Failed to queue WarmMarkdownCacheJob: #{e.message}")
        Rails.cache.delete(lock_key)
        raise
      end
    else
      puts "WarmMarkdownCacheJob already queued by another process"
    end
  end
end
