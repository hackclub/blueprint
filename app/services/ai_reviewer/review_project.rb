module AiReviewer
  class ReviewProject
    MODEL = "openai/gpt-5-nano"
    PROVIDER = :openrouter

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

      log "Setting up chat with model=#{MODEL}, tools: GetJournal, GetRepoTree, GetFileContent"
      chat = RubyLLM.chat(model: MODEL, provider: PROVIDER)
        .with_tools(
          Tools::GetJournal.new(@project),
          Tools::GetRepoTree.new(@project),
          Tools::GetFileContent.new(@project)
        )

      chat.with_instructions(system_prompt)
      log "Sending prompt to #{MODEL}... (this may take a while)"
      response = chat.ask(user_prompt)
      log "Got response (#{response.content.to_s.length} chars)"

      analysis = parse_json(response.content)
      if analysis["parse_error"]
        log "WARNING: Failed to parse JSON from response, storing raw content"
      else
        score = analysis["guideline_score"]
        checks = analysis["checks"]&.size || 0
        log "Parsed analysis: score=#{score}, #{checks} checks"
      end

      input_tokens = response.input_tokens.to_i
      output_tokens = response.output_tokens.to_i
      total = input_tokens + output_tokens
      log "Tokens: #{input_tokens} in + #{output_tokens} out = #{total} total"

      ai_review.update!(
        status: :completed,
        analysis: analysis,
        raw_response: response.content,
        model_used: MODEL,
        prompt_tokens: input_tokens,
        completion_tokens: output_tokens,
        total_tokens: total,
        completed_at: Time.current
      )
      log "Review complete for project ##{@project.id} (AiReview ##{ai_review.id})"
      ai_review
    rescue => e
      ai_review&.update!(
        status: :failed,
        error_message: "#{e.class}: #{e.message}",
        completed_at: Time.current
      )
      log "FAILED for project ##{@project.id}: #{e.class}: #{e.message}", level: :error
      Sentry.capture_exception(e, extra: { project_id: @project.id, review_phase: @review_phase }) if defined?(Sentry)
      ai_review
    end

    private

    def system_prompt
      guide = Rails.root.join("docs/ai_reviewer_guide.md").read

      <<~PROMPT
        You are an AI review assistant for Blueprint, a hardware project submission platform run by Hack Club.

        Your role is to ASSIST human reviewers by analyzing submissions against the reviewer guide below. You do NOT make approval/rejection decisions — you provide structured analysis that helps human reviewers work faster.

        ## Reviewer Guide

        #{guide}

        ## Your Process

        Think step-by-step. For each step:

        1. Thought: Reason about what you know and what you still need to investigate.
        2. Action: Call a tool to gather the information you need.
        3. Observation: Review the tool result.
        4. Repeat until you have enough evidence to evaluate every checklist item.

        Recommended investigation flow:
        - Start by reading the journal to understand the project and assess documentation quality
        - Then get the repo tree to see what files exist
        - Then read key files
        - Read any other files that seem relevant based on the tree

        When you have gathered enough evidence, respond with ONLY the JSON object specified in the output format above. No markdown fences, no extra text — just the JSON.
      PROMPT
    end

    def user_prompt
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
      lines << "Begin your analysis."

      lines.join("\n")
    end

    def log(message, level: :info)
      Rails.logger.public_send(level, "[AiReviewer] [project:#{@project.id}] #{message}")
    end

    def parse_json(content)
      cleaned = content.to_s.strip
      cleaned = cleaned.sub(/\A```json\s*\n?/, "").sub(/\n?```\s*\z/, "")
      JSON.parse(cleaned)
    rescue JSON::ParserError
      { "parse_error" => true, "raw_content" => content.to_s.truncate(5000) }
    end
  end
end
