module AiReviewer
  class ReviewProject
    include AiReviewer::GithubClient

    MODEL = "google/gemini-2.5-flash"
    PROVIDER = :openrouter
    LLM_TIMEOUT = 10.minutes

    class CancelledError < StandardError; end

    def initialize(project:, review_phase:)
      @project = project
      @review_phase = review_phase
    end

    def call
      log "Starting #{@review_phase} review for project ##{@project.id} (#{@project.title.truncate(50)})"

      ai_review = AiReview.create!(
        project: @project,
        review_phase: @review_phase,
        status: :running,
        started_at: Time.current
      )
      log "Created AiReview ##{ai_review.id}, status=running"

      # Pre-fetch journal and repo tree
      journal_content = fetch_journal
      repo_tree_content, known_paths = fetch_repo_tree
      log "Pre-fetched journal (#{journal_content.length} chars) and repo tree (#{known_paths.size} files)"

      seen_resources = Set.new

      file_content_tool = Tools::GetFileContent.new(@project, known_paths: known_paths, seen_resources: seen_resources)

      all_tools = [
        file_content_tool,
        Tools::GetImage.new(@project, known_paths: known_paths, seen_resources: seen_resources),
        Tools::ResearchAssistant.new(@project),
        Tools::Oracle.new(@project),
        Tools::QueryBlueprintDocs.new(@project),
        Tools::QueryHardwareDocs.new(@project),
        Tools::ViewKicadSchematic.new(@project, seen_resources: seen_resources),
        Tools::ViewKicadPcb.new(@project, seen_resources: seen_resources),
        Tools::RenderStepFile.new(@project, seen_resources: seen_resources),
        Tools::RenderStlFile.new(@project, seen_resources: seen_resources),
        Tools::CheckLinkValidity.new(@project),
        Tools::SubmitResearch.new(@project)
      ]
      tool_names = all_tools.map { |t| t.class.name.demodulize }.join(", ")
      log "Setting up chat with model=#{MODEL}, tools: #{tool_names}"
      tool_call_count = 0
      cumulative_input_tokens = 0
      cumulative_output_tokens = 0

      submit_research = all_tools.find { |t| t.is_a?(Tools::SubmitResearch) }
      research_assistant = all_tools.find { |t| t.is_a?(Tools::ResearchAssistant) }

      # Live-stream nested steps from ResearchAssistant to the DB
      research_assistant.step_callback = ->(nested_step) {
        ai_review.with_lock do
          steps = ai_review.steps.dup
          call_idx = steps.rindex { |s| s["type"] == "tool_call" && s["n"] == tool_call_count }
          if call_idx
            steps[call_idx]["nested_steps"] ||= []
            steps[call_idx]["nested_steps"] << nested_step
            ai_review.update_columns(steps: steps)
          end
        end
      }

      chat = RubyLLM.chat(model: MODEL, provider: PROVIDER)
        .with_tools(*all_tools)
        .on_end_message do |message|
          # Accumulate tokens across all API round-trips (each turn re-sends full context)
          cumulative_input_tokens += message.input_tokens.to_i
          cumulative_output_tokens += message.output_tokens.to_i
        end
        .on_tool_call do |tool_call|
          check_cancelled!(ai_review)
          tool_call_count += 1
          current_n = tool_call_count
          step = {
            type: "tool_call",
            n: current_n,
            tool: tool_call.name,
            args: tool_call.arguments,
            timestamp: Time.current.iso8601
          }
          log "##{current_n} #{tool_call.name}(#{tool_call.arguments.to_json.truncate(200)})"

          # Feed tool call history to SubmitResearch (excluding SubmitResearch itself)
          submit_research&.record_tool_call(tool_call.name, tool_call.arguments) unless tool_call.name == "submit_research"

          ai_review.with_lock do
            steps = ai_review.steps.dup
            steps << step
            ai_review.update_columns(steps: steps)
          end
        end
        .on_tool_result do |result|
          result_preview = (result.is_a?(RubyLLM::Content) ? result.text.to_s : result.to_s).truncate(500)
          submit_research&.record_tool_result(result_preview)

          step = {
            type: "tool_result",
            n: tool_call_count,
            result: result_preview,
            timestamp: Time.current.iso8601
          }

          # Extract base64 thumbnails from Content results (GetImage, render tools)
          if result.is_a?(RubyLLM::Content)
            thumbnails = extract_thumbnails(result)
            step["images"] = thumbnails if thumbnails.present?
          end

          log "│ result: #{result_preview.truncate(200)}"
          ai_review.with_lock do
            steps = ai_review.steps.dup
            call_idx = steps.rindex { |s| s["type"] == "tool_call" && s["n"] == tool_call_count }
            if call_idx
              steps.insert(call_idx + 1, step)
            else
              steps << step
            end
            ai_review.update_columns(steps: steps)
          end
        end

      chat.with_instructions(system_prompt)
      log "Sending prompt to #{MODEL}... (this may take a while)"
      response = Timeout.timeout(LLM_TIMEOUT, nil, "LLM call timed out after #{LLM_TIMEOUT.to_i}s") do
        chat.ask(user_prompt(journal_content, repo_tree_content))
      end
      log "Got response after #{tool_call_count} tool calls (#{response.content.to_s.length} chars)"
      check_cancelled!(ai_review)

      # Enforce SubmitResearch gate: the model must get APPROVED from SubmitResearch before
      # writing its final review. If it didn't, or if it got NEEDS MORE RESEARCH and forgot
      # to resubmit, nudge it.
      if submit_research.approved_summary.nil?
        log "SubmitResearch not approved — re-prompting model"
        response = Timeout.timeout(LLM_TIMEOUT, nil, "LLM call timed out after #{LLM_TIMEOUT.to_i}s") do
          chat.ask("Your research has NOT been approved yet. You must call the SubmitResearch tool with a thorough, updated project summary that includes everything you've learned so far. Do not write your review until SubmitResearch returns APPROVED. Call SubmitResearch now.")
        end

        if submit_research.approved_summary.nil?
          log "SubmitResearch still not approved after first nudge — trying once more"
          response = Timeout.timeout(LLM_TIMEOUT, nil, "LLM call timed out after #{LLM_TIMEOUT.to_i}s") do
            chat.ask("SubmitResearch has still not returned APPROVED. Call SubmitResearch now with your complete project summary, then write your final review.")
          end
        end

        if submit_research.approved_summary.nil?
          log "SubmitResearch gate failed after 2 nudges — bypassing and requesting final review", level: :warn
          response = Timeout.timeout(LLM_TIMEOUT, nil, "LLM call timed out after #{LLM_TIMEOUT.to_i}s") do
            chat.ask("The research validation step is unavailable. Skip it and write your final review now based on what you've already learned. Include Project Understanding, Review Summary with Result: PASS or FAIL, Feedback, and the JSON checklist.")
          end
        end
      end

      # Detect Gemini tool_code bug: model outputs Python-style function calls as text
      # instead of using proper tool calling. Re-prompt to get an actual review.
      max_retries = 2
      retries = 0
      while retries < max_retries
        response_text = response.content.to_s
        break unless response_text.start_with?("tool_code") || response_text.match?(/\Aprint\(default_api\./)

        retries += 1
        log "Gemini tool_code bug detected (attempt #{retries}/#{max_retries}), re-prompting for review..."
        response = Timeout.timeout(LLM_TIMEOUT, nil, "LLM call timed out after #{LLM_TIMEOUT.to_i}s") do
          chat.ask("You returned a tool_code block instead of your review. Do NOT call any more tools. Write your final review now — include Project Understanding, Review Summary with Result: PASS or FAIL, Feedback, and the JSON checklist.")
        end
      end

      response_text = response.content.to_s
      if response_text.start_with?("tool_code") || response_text.match?(/\Aprint\(default_api\./)
        raise "Model returned tool_code #{max_retries + 1} times. This is a known Gemini bug — please retry."
      end

      # Sanity check: response should contain review content (JSON checklist or result verdict)
      unless response_text.include?("guideline_score") || response_text.match?(/Result:\s*(PASS|FAIL)/i)
        log "WARNING: Response doesn't appear to contain a review verdict", level: :warn
      end

      # Log the approved research summary as a separate step
      if submit_research&.approved_summary.present?
        research_step = {
          type: "research_summary",
          summary: submit_research.approved_summary,
          timestamp: Time.current.iso8601
        }
        ai_review.with_lock do
          steps = ai_review.steps.dup
          steps << research_step
          ai_review.update_columns(steps: steps)
        end
        log "Research summary saved (#{submit_research.approved_summary.length} chars)"
      end

      analysis = parse_json(response.content)
      if analysis["parse_error"]
        log "WARNING: Failed to parse JSON from response, storing raw content"
      else
        score = analysis["guideline_score"]
        checks = analysis["checks"]&.size || 0
        log "Parsed analysis: score=#{score}, #{checks} checks"
      end

      total = cumulative_input_tokens + cumulative_output_tokens
      log "Tokens: #{cumulative_input_tokens} in + #{cumulative_output_tokens} out = #{total} total (across all turns)"

      breakdown = build_cost_breakdown(cumulative_input_tokens, cumulative_output_tokens, all_tools)
      estimated_cost_cents = breakdown[:total_cost_cents]
      log "Estimated cost: $#{'%.4f' % (estimated_cost_cents / 100.0)} (#{estimated_cost_cents} cents)"

      # Store cost breakdown as a step
      ai_review.with_lock do
        steps = ai_review.steps.dup
        steps << { type: "cost_breakdown", breakdown: breakdown, timestamp: Time.current.iso8601 }
        ai_review.update_columns(steps: steps)
      end

      ai_review.update!(
        status: :completed,
        analysis: analysis,
        raw_response: response.content,
        model_used: MODEL,
        prompt_tokens: cumulative_input_tokens,
        completion_tokens: cumulative_output_tokens,
        total_tokens: total,
        estimated_cost_cents: estimated_cost_cents,
        completed_at: Time.current
      )
      log "Review complete for project ##{@project.id} (AiReview ##{ai_review.id})"
      ai_review
    rescue CancelledError => e
      log "Cancelled: #{e.message}"
      ai_review
    rescue => e
      log "FAILED for project ##{@project.id}: #{e.class}: #{e.message}", level: :error
      Sentry.capture_exception(e, extra: { project_id: @project.id, review_phase: @review_phase }) if defined?(Sentry)
      begin
        ai_review&.update!(
          status: :failed,
          error_message: "#{e.class}: #{e.message}".truncate(1000),
          completed_at: Time.current
        )
      rescue => update_error
        log "Failed to update AiReview ##{ai_review&.id} to failed status: #{update_error.message}", level: :error
      end
      ai_review
    end

    private

    def fetch_journal
      entries = @project.journal_entries.order(created_at: :asc)
      return "No journal entries found." if entries.empty?

      total_hours = (entries.sum(:duration_seconds) / 3600.0).round(2)
      lines = [ "# Journal — #{entries.count} entries, #{total_hours} total hours\n" ]

      entries.each_with_index do |entry, i|
        hours = (entry.duration_seconds / 3600.0).round(2)
        lines << "## Entry #{i + 1}: #{entry.summary} (#{hours}h) — #{entry.created_at.strftime('%Y-%m-%d')}"
        lines << entry.content.to_s
        lines << ""
      end

      lines.join("\n").truncate(50_000)
    end

    def fetch_repo_tree
      parsed = @project.parse_repo
      unless parsed && parsed[:org].present? && parsed[:repo_name].present?
        return [ "No GitHub repo linked.", Set.new ]
      end

      path = "/repos/#{parsed[:org]}/#{parsed[:repo_name]}/git/trees/HEAD?recursive=1"
      response = github_fetch(path)
      unless response.status == 200
        return [ "Failed to fetch repo tree (HTTP #{response.status}).", Set.new ]
      end

      data = JSON.parse(response.body)
      tree = data["tree"] || []

      original_file_count = tree.count { |i| i["type"] == "blob" }
      original_dir_count = tree.count { |i| i["type"] == "tree" }

      excluded_dirs = Tools::GetRepoTree::EXCLUDED_DIRS
      tree = tree.reject { |item| item["path"].split("/").any? { |part| excluded_dirs.include?(part) } }

      # Filter out journal files
      journal_pattern = Tools::GetRepoTree::JOURNAL_PATTERN
      tree = tree.reject { |item| item["type"] == "blob" && File.basename(item["path"]) =~ journal_pattern }

      # Collect known file paths for GetFileContent validation
      known_paths = Set.new(tree.select { |i| i["type"] == "blob" }.map { |i| i["path"] })

      file_count = tree.count { |i| i["type"] == "blob" }
      dir_count = tree.count { |i| i["type"] == "tree" }
      total_entries = tree.size
      max_entries = Tools::GetRepoTree::MAX_ENTRIES
      truncated = total_entries > max_entries
      tree = tree.first(max_entries) if truncated

      visual_hints = Tools::GetRepoTree::VISUAL_TOOL_HINTS
      image_exts = Tools::GetRepoTree::IMAGE_EXTENSIONS

      lines = []
      lines << "# Repository: #{parsed[:org]}/#{parsed[:repo_name]}"
      lines << "#{file_count} files, #{dir_count} directories (#{original_file_count} files, #{original_dir_count} directories before filtering excluded dirs)"
      lines << "Note: Journal entries are provided separately above.\n"

      tree.each do |item|
        if item["type"] == "tree"
          lines << "#{item['path']}/"
        else
          size = item["size"].to_i
          item_path = item["path"]
          ext = File.extname(item_path).downcase

          if visual_hints.key?(ext)
            tool = visual_hints[ext]
            lines << "#{item_path} (#{size} bytes) [binary — use #{tool} to view]"
          elsif image_exts.include?(ext)
            lines << "#{item_path} (#{size} bytes) [image — use GetImage to view]"
          else
            est_lines = size > 0 ? (size / 40.0).ceil : 0
            lines << "#{item_path} (#{size} bytes, ~#{est_lines} lines)"
          end
        end
      end

      lines << "\n(Showing #{max_entries} of #{total_entries} entries. Tree was truncated.)" if truncated

      [ lines.join("\n"), known_paths ]
    end

    def system_prompt
      base_guide = Rails.root.join("docs/ai_reviewer_guide.md").read
      phase_guide_file = @review_phase == "design" ? "ai_reviewer_guide_design.md" : "ai_reviewer_guide_build.md"
      phase_guide = Rails.root.join("docs/#{phase_guide_file}").read

      <<~PROMPT
        #{base_guide}

        ## Phase-Specific Checklist

        #{phase_guide}
      PROMPT
    end

    def user_prompt(journal_content, repo_tree_content)
      project = @project
      phase_label = @review_phase == "design" ? "DESIGN REVIEW" : "BUILD REVIEW"

      hours = (project.journal_entries.sum(:duration_seconds) / 3600.0).round(2)

      lines = []
      lines << "Analyze project ##{project.id} \"#{project.title}\" for #{phase_label}."
      lines << ""
      lines << "## Project Info"
      lines << "- Title: #{project.title}"
      lines << "- Description: #{project.description}"
      lines << "- Tier: #{project.tier || 'Not set'}"
      lines << "- Funding requested: $#{'%.2f' % (project.funding_needed_cents / 100.0)}"
      lines << "- Type: #{project.ysws || 'Custom'}"
      lines << "- Repo: #{project.repo_link || 'Not linked'}"
      lines << "- Journal entries: #{project.journal_entries_count}"
      lines << "- Total hours: #{hours}"

      if project.reviewer_note.present?
        lines << "- Note to reviewer from author. This is good to take in account, but shouldn't trusted as the source of truth. Rely on the guidelines above.: \"#{project.reviewer_note}\""
      end

      lines << ""
      lines << "## Previous Human Reviews"

      design_reviews = project.design_reviews.order(created_at: :desc)
      build_reviews = project.build_reviews.order(created_at: :desc)

      if design_reviews.empty? && build_reviews.empty?
        lines << "No previous human reviews."
      else
        design_reviews.each do |r|
          status = r.invalidated? ? " (OUTDATED)" : ""
          lines << "- Design review#{status}: #{r.result} — #{r.feedback}" if r.feedback.present?
        end
        build_reviews.each do |r|
          status = r.invalidated? ? " (OUTDATED)" : ""
          lines << "- Build review#{status}: #{r.result} — #{r.feedback}" if r.feedback.present?
        end
      end

      lines << ""
      lines << "## Project Journal"
      lines << ""
      lines << journal_content
      lines << ""
      lines << "## Repository File Tree"
      lines << ""
      lines << repo_tree_content
      lines << ""
      lines << "Begin your analysis. The journal and file tree are above — start by reading the README and BOM with GetFileContent."

      lines.join("\n")
    end

    # Pricing per million tokens (USD)
    # gemini-2.5-flash:  $0.30 input, $2.50 output
    # gpt-5-nano:        $0.05 input, $0.40 output (SubmitResearch, ResearchAssistant)
    # claude-3.5-haiku:  $1.00 input, $5.00 output (Oracle)
    # Bright Data SERP:  $1.50 per 1,000 requests
    def build_cost_breakdown(input_tokens, output_tokens, tools)
      oracle = tools.find { |t| t.is_a?(Tools::Oracle) }
      sr = tools.find { |t| t.is_a?(Tools::SubmitResearch) }
      ra = tools.find { |t| t.is_a?(Tools::ResearchAssistant) }

      agents = []

      # Main agent (gemini-2.5-flash)
      main_ai_cost = (input_tokens * 0.30 + output_tokens * 2.50) / 1_000_000.0
      agents << { name: "main", model: MODEL, input_tokens: input_tokens, output_tokens: output_tokens, ai_cost: main_ai_cost, serp_cost: 0.0 }

      # ResearchAssistant calls (gpt-5-nano + SERP)
      if ra
        ra.call_stats.each_with_index do |stat, i|
          ai_cost = (stat[:input_tokens] * 0.05 + stat[:output_tokens] * 0.40) / 1_000_000.0
          agents << { name: "research ##{i + 1}", model: Tools::ResearchAssistant::AGENT_MODEL, input_tokens: stat[:input_tokens], output_tokens: stat[:output_tokens], ai_cost: ai_cost, serp_cost: stat[:serp_cost] }
        end
      end

      # Oracle calls (claude-3.5-haiku)
      if oracle
        oracle.call_stats.each_with_index do |stat, i|
          ai_cost = (stat[:input_tokens] * 1.00 + stat[:output_tokens] * 5.00) / 1_000_000.0
          agents << { name: "oracle ##{i + 1}", model: Tools::Oracle::ORACLE_MODEL, input_tokens: stat[:input_tokens], output_tokens: stat[:output_tokens], ai_cost: ai_cost, serp_cost: 0.0 }
        end
      end

      # SubmitResearch calls (gpt-5-nano)
      if sr
        sr.call_stats.each_with_index do |stat, i|
          ai_cost = (stat[:input_tokens] * 0.05 + stat[:output_tokens] * 0.40) / 1_000_000.0
          agents << { name: "gate ##{i + 1}", model: Tools::SubmitResearch::VALIDATOR_MODEL, input_tokens: stat[:input_tokens], output_tokens: stat[:output_tokens], ai_cost: ai_cost, serp_cost: 0.0 }
        end
      end

      total_ai = agents.sum { |a| a[:ai_cost] }
      total_serp = agents.sum { |a| a[:serp_cost] }
      total_all = total_ai + total_serp

      {
        agents: agents,
        totals: {
          input_tokens: agents.sum { |a| a[:input_tokens] },
          output_tokens: agents.sum { |a| a[:output_tokens] },
          ai_cost: total_ai,
          serp_cost: total_serp,
          all_cost: total_all
        },
        total_cost_cents: (total_all * 100).ceil
      }
    end

    def extract_thumbnails(content)
      return [] unless content.respond_to?(:attachments) && content.attachments.present?

      content.attachments.filter_map do |attachment|
        path = attachment.source.to_s
        next unless path.present? && File.exist?(path)

        image = Vips::Image.new_from_file(path)
        thumb = image.thumbnail_image(300, height: 300, size: :down)
        data = thumb.jpegsave_buffer(Q: 40)
        Base64.strict_encode64(data)
      rescue StandardError => e
        log "Failed to create thumbnail: #{e.message}", level: :warn
        nil
      end
    end

    def check_cancelled!(ai_review)
      return unless ai_review.reload.status_failed?

      raise CancelledError, "Review ##{ai_review.id} was cancelled externally"
    end

    def log(message, level: :info)
      Rails.logger.public_send(level, "[AiReviewer] [project:#{@project.id}] #{message}")
    end

    def parse_json(content)
      text = content.to_s.strip

      # Try extracting JSON from a ```json code fence first
      if text =~ /```json\s*\n(.*?)\n```/m
        return JSON.parse($1.strip)
      end

      # Fall back: find the last { ... } block in the response (the JSON checklist)
      if text =~ /(\{[^{}]*("checks"|"guideline_score")[^{}]*\{.*\}.*\})/m
        return JSON.parse($1.strip)
      end

      # Last resort: try parsing the whole thing as JSON
      JSON.parse(text)
    rescue JSON::ParserError
      { "parse_error" => true, "raw_content" => text.truncate(5000) }
    end
  end
end
