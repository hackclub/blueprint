module AiReviewer
  module Tools
    class SubmitResearch < RubyLLM::Tool
      description "REQUIRED before giving your verdict. Submit everything you've learned about the project for validation. A second reviewer will check whether your research is sufficient or if you missed something. You MUST call this tool before writing your final review."

      VALIDATOR_MODEL = "openai/gpt-5-nano"
      VALIDATOR_TIMEOUT = 120

      params do
        string :project_info, description: "A detailed list of everything you've learned about the project. Include: what the project is and its purpose, how it works, every key component and what it does, how they connect and communicate (voltages, protocols, pins), the build approach, and any concerns or red flags. Be specific — cite part numbers and file paths. This is not a summary — list out your findings."
      end

      attr_reader :total_input_tokens, :total_output_tokens, :approved_summary, :call_stats

      def initialize(project)
        @project = project
        @total_input_tokens = 0
        @total_output_tokens = 0
        @call_stats = []
        @tool_call_history = []
        @approved_summary = nil
        super()
      end

      # Called by review_project.rb on each tool call to build the history
      def record_tool_call(name, arguments)
        @tool_call_history << { tool: name, args: arguments, result: nil }
      end

      # Called by review_project.rb on each tool result to record outcome
      def record_tool_result(result_str)
        last = @tool_call_history.last
        return unless last

        failed = result_str.match?(/error|not found|failed|timed out/i) && !result_str.match?(/binary file|use the \w+ tool/i)
        last[:result] = failed ? "FAILED: #{result_str.truncate(200)}" : "ok"
      end

      def execute(project_info:)
        Rails.logger.info("[AiReviewer] [project:#{@project.id}] Tool call: SubmitResearch (#{project_info.length} chars, #{@tool_call_history.size} prior tool calls)")

        chat = RubyLLM.chat(model: VALIDATOR_MODEL, provider: :openrouter)
        chat.with_instructions(validator_system_prompt)

        question = <<~PROMPT
          ## Research Summary

          #{project_info}

          ## Actual Tool Call History (#{@tool_call_history.size} calls)

          #{format_tool_history}
        PROMPT

        response = Timeout.timeout(VALIDATOR_TIMEOUT) { chat.ask(question) }

        @total_input_tokens += response.input_tokens.to_i
        @total_output_tokens += response.output_tokens.to_i
        @call_stats << { input_tokens: response.input_tokens.to_i, output_tokens: response.output_tokens.to_i }
        Rails.logger.info("[AiReviewer] [project:#{@project.id}] SubmitResearch: #{response.input_tokens} in + #{response.output_tokens} out tokens")

        result = response.content.to_s.truncate(5000)

        if result.match?(/Status:\s*APPROVED/i) && !result.match?(/Status:\s*NEEDS MORE RESEARCH/i)
          @approved_summary = project_info
        end

        "Research Validation:\n\n#{result}"
      rescue Timeout::Error
        Rails.logger.error("[AiReviewer] [project:#{@project.id}] SubmitResearch error: Timed out after #{VALIDATOR_TIMEOUT}s")
        "Research validation failed (timed out). Please call SubmitResearch again to retry."
      rescue StandardError => e
        Rails.logger.error("[AiReviewer] [project:#{@project.id}] SubmitResearch error: #{e.message}")
        "Research validation failed. Please call SubmitResearch again to retry."
      end

      private

      def format_tool_history
        return "No tool calls recorded." if @tool_call_history.empty?

        @tool_call_history.map.with_index(1) do |call, i|
          args_str = call[:args].to_json.truncate(300)
          status = call[:result] == "ok" ? "" : " → #{call[:result]}"
          "#{i}. #{call[:tool]}(#{args_str})#{status}"
        end.join("\n")
      end

      def validator_system_prompt
        <<~PROMPT
          You are a research validator for Blueprint hardware project reviews. A reviewer has investigated a teenager's hardware project submission and is about to pass or fail it.

          Your job: check whether the reviewer did enough research to make a fair decision. You are NOT judging the project — you are judging whether the REVIEWER looked at enough things.

          You will receive:
          1. The reviewer's summary of what they learned
          2. The tool call history — every tool the reviewer called

          ## What counts as sufficient research

          The reviewer MUST have done ALL of these (check the tool call history):
          - Read the README (via GetFileContent for README.md) — this is mandatory, no exceptions
          - Looked at at least one image (via GetImage) if images exist in the repo — filenames are not evidence
          - Read at least one source code or firmware file (via GetFileContent) if the project has code
          - Researched at least one key component (via ResearchAssistant) to understand what it is and whether it's appropriate
          - Checked BOM purchase links (via CheckLinkValidity) if a BOM exists

          The reviewer's summary should ALSO demonstrate:
          - Specific understanding of the project, not vague hand-waving
          - How key components fit together (voltages, protocols, physical connections) — not just a list of parts
          - Whether the project is plausibly buildable as a whole, not just individual items checked off
          - Whether the README is reasonably formatted and parseable (not a wall of text)

          ## Important: don't be pedantic

          - Journal entries are provided directly in the prompt — they do NOT need GetFileContent to read them
          - File tree line counts are estimates — if GetFileContent returns more or fewer lines, that's normal
          - Binary files (.ork, .stl, .step, etc.) cannot be read as text — don't demand the reviewer read them
          - Failed tool calls are NOT the reviewer's fault — if a fetch fails, they tried
          - Don't require the reviewer to check BOM prices — that's for the human reviewer. But they should have used CheckLinkValidity to verify links are live.
          - The reviewer uses CheckLinkValidity for link validation (not ResearchAssistant) — look for CheckLinkValidity calls
          - The reviewer uses ResearchAssistant for web research (which delegates to WebSearch/WebFetch internally) — look for ResearchAssistant calls, not direct WebSearch/WebFetch calls
          - For very simple projects (single PCB, no enclosure, minimal components), be more lenient on buildability analysis

          ## Response format

          **Status: APPROVED** or **Status: NEEDS MORE RESEARCH**

          [If APPROVED: one sentence confirming the research looks thorough]
          [If NEEDS MORE RESEARCH: 1-3 specific, actionable gaps. Only flag things that are genuinely missing and would change the review outcome.]

          Check the tool call history against the mandatory items above. If any mandatory item was skipped (and applies to this project), reject. Approve only when all applicable mandatory items were done and the summary demonstrates real understanding of how the project fits together.
        PROMPT
      end
    end
  end
end
