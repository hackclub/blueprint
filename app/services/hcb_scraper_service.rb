class HcbScraperService
  class << self
    def base_url
      ENV.fetch("HCB_URL", "https://hcb.hackclub.com/")
    end

    def default_org_id
      ENV.fetch("ORG_ID", "ysws-blueprint")
    end

    def max_concurrency
      ENV.fetch("HCB_MAX_THREADS", "10").to_i
    end

    def connection
      @connection ||= Faraday.new(url: base_url) do |f|
        f.adapter Faraday.default_adapter
      end
    end

    def fetch_grants(org_id = nil, fast: true)
      org_id = default_org_id if org_id.nil? || org_id.strip.empty?

      raw_response = with_retry do
        connection.get("#{org_id}/transfers")
      end

      unless raw_response.success?
        Rails.logger.error("HCB request failed to get grants: #{raw_response.status} - #{raw_response.body}")
        Sentry.capture_message("HCB request failed to get grants: #{raw_response.status} - #{raw_response.body}")
        return []
      end

      doc = Nokogiri::HTML(raw_response.body)
      pages = get_page_count(doc)
      Rails.logger.info "Found #{pages} pages of grants"

      grants = parse_grants_from_page(doc, org_id)
      Rails.logger.info "Found #{grants.size} grants on page 1"

      if pages > 1
        if fast
          (2..pages).each_slice(max_concurrency) do |page_nums|
            threads = page_nums.map do |page_num|
              Thread.new do
                page_response = with_retry do
                  connection.get("#{org_id}/transfers?page=#{page_num}")
                end

                if page_response.success?
                  page_doc = Nokogiri::HTML(page_response.body)
                  page_grants = parse_grants_from_page(page_doc, org_id)
                  Rails.logger.info "Found #{page_grants.size} grants on page #{page_num}"
                  page_grants
                else
                  Rails.logger.error("HCB request failed to get page #{page_num}: #{page_response.status}")
                  []
                end
              end
            end

            page_grants = threads.map(&:value).flatten
            grants.concat(page_grants)
          end
        else
          (2..pages).each do |page_num|
            page_response = with_retry do
              connection.get("#{org_id}/transfers?page=#{page_num}")
            end

            if page_response.success?
              page_doc = Nokogiri::HTML(page_response.body)
              page_grants = parse_grants_from_page(page_doc, org_id)
              Rails.logger.info "Found #{page_grants.size} grants on page #{page_num}"
              grants.concat(page_grants)
            else
              Rails.logger.error("HCB request failed to get page #{page_num}: #{page_response.status}")
            end
          end
        end
      end

      Rails.logger.info "Total grants found: #{grants.size}"

      if fast
        grants.each_slice(max_concurrency) do |grant_slice|
          threads = grant_slice.map do |grant_hash|
            Thread.new { fetch_grant_details(grant_hash) }
          end
          threads.each(&:join)
        end
      else
        grants.each do |grant_hash|
          fetch_grant_details(grant_hash)
        end
      end

      total_transactions = grants.sum { |g| g[:transactions]&.size || 0 }
      successful_grants = grants.count { |g| g[:transactions] || g[:balance_cents] || g[:to_user_avatar] }
      failed_grants = grants.size - successful_grants

      Rails.logger.info "\n--- Fetch Summary ---"
      Rails.logger.info "Total transactions found: #{total_transactions}"
      Rails.logger.info "Total grants successfully fetched: #{successful_grants}"
      Rails.logger.info "Total grants failed: #{failed_grants}"
      Rails.logger.info "---------------------\n"

      grants
    end

    private

    def fetch_grant_details(grant_hash)
      grant_id = grant_hash[:grant_id]
      raw_response = with_retry do
        connection.get("/grants/#{grant_id}/spending")
      end

      unless raw_response.success?
        Rails.logger.error("HCB request failed to get grant #{grant_id}: #{raw_response.status} - #{raw_response.body}")
        Sentry.capture_message("HCB request failed to get grant #{grant_id}: #{raw_response.status} - #{raw_response.body}")
        return
      end

      doc = Nokogiri::HTML(raw_response.body)

      doc.css("span").each do |span|
        if span.text.strip.start_with?("issued about ")
          img = span.previous_element.at_css("img")["src"] rescue nil
          grant_hash[:to_user_avatar] ||= img
          break
        end
      end

      doc.css("span").each do |span|
        if span.text.strip == "Balance remaining"
          amount_text = span.next_element.text.strip.delete("$,") rescue nil
          grant_hash[:balance_cents] ||= (amount_text.to_f * 100).to_i if amount_text
          break
        end
      end

      transactions = []
      doc.css("turbo-frame").each do |frame|
        next unless frame["class"]&.include?("memo-frame")

        transaction_id = frame["id"].split(":").first rescue nil
        status_ele = frame.previous_element rescue nil
        status = status_ele.text.strip if status_ele.name == "span" rescue nil
        amount_cents = (frame.parent.parent.parent.parent.next_element.text.strip.delete("$,").to_f * 100).to_i rescue nil
        receipt_count = frame.parent.parent.next_element.text.strip.to_i rescue nil
        memo = frame.at_css("span").at_css("a").text.strip rescue nil
        created_at_text = frame.parent.parent.parent.parent.previous_element.at_css("time")["datetime"] rescue nil
        created_at = Time.parse(created_at_text) rescue nil

        transactions << {
          transaction_id: transaction_id,
          status: status,
          amount_cents: amount_cents,
          receipt_count: receipt_count,
          memo: memo,
          hcb_created_at: created_at
        }
      end

      Rails.logger.info "Found #{transactions.size} transactions for grant #{grant_id}"
      grant_hash[:transactions] = transactions
    end

    def get_page_count(doc)
      # search for a with "Last »"
      doc.css("a").each do |link|
        if link.text.strip == "Last »"
          href = link["href"]
          if href =~ /page=(\d+)/
            return $1.to_i
          end
        end
      end
      1
    end

    def parse_grants_from_page(doc, org_id)
      grants = []
      doc.css("a").each do |link|
        href = link["href"]
        next unless href =~ %r{^/grants/([^/]+)/spending$}

        grant_id = $1
        status = link.parent.parent.previous_element.previous_element.at_css("span").text.strip rescue nil
        initial_amount_cents = (link.parent.parent.next_element.next_element.text.strip.delete("$,").to_f * 100).to_i rescue nil
        to_user_name = link.text.strip rescue nil
        for_reason = link.parent.parent.next_element.text.strip rescue nil
        created_at_text = link.parent.parent.previous_element.at_css("time")["datetime"] rescue nil
        issued_at = Time.parse(created_at_text) rescue nil

        grants << {
          org_id: org_id,
          grant_id: grant_id,
          status: status,
          initial_amount_cents: initial_amount_cents,
          to_user_name: to_user_name,
          for_reason: for_reason,
          issued_at: issued_at,
          source_url: "#{base_url}grants/#{grant_id}/spending"
        }
      end
      grants
    end

    def with_retry(max = 3)
      retries = 0
      begin
        yield
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError, SocketError => e
        retries += 1
        if retries <= max
          Rails.logger.warn "HCB request failed (try #{retries}/#{max + 1}): #{e.message}"
          sleep(0.5 * retries)
          retry
        else
          Rails.logger.error "HCB request failed after retry: #{e.message}"
          Sentry.capture_exception(e)
          raise
        end
      end
    end
  end
end
