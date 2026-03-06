module AiReviewer
  module Tools
    class ResearchAssistant < RubyLLM::Tool
      AGENT_MODEL = "openai/gpt-5-nano"
      AGENT_PROVIDER = :openrouter
      AGENT_TIMEOUT = 300
      MAX_SEARCH_REQUESTS = 10
      MAX_FETCH_REQUESTS = 5

      description "Delegate web research to a research assistant ONLY when you genuinely need external information you don't already know. Good uses: looking up obscure component datasheets, verifying specific product listings (e.g. AliExpress links), checking compatibility between specific parts you're unfamiliar with. Do NOT use this for basic questions you can answer from your training knowledge (e.g. 'what is an ESP32', 'what voltage does USB-C provide', 'what is I2C'). The assistant will search and browse the web, then return a concise summary. Be specific about what you need."

      params do
        string :task, description: "What to research — be specific about what you need to know and why. Include URLs, part numbers, or search terms as needed."
      end

      attr_reader :total_input_tokens, :total_output_tokens, :total_serp_cost, :call_stats
      attr_writer :step_callback

      def initialize(project)
        @project = project
        @total_input_tokens = 0
        @total_output_tokens = 0
        @total_serp_cost = 0.0
        @call_stats = []
        @nested_tool_count = 0
        @step_callback = nil
        super()
      end

      def execute(task:)
        Rails.logger.info("[AiReviewer] [project:#{@project.id}] Tool call: ResearchAssistant(#{task.truncate(100)})")

        prev_input = @total_input_tokens
        prev_output = @total_output_tokens
        prev_serp = @total_serp_cost

        search_counter = { count: 0, limit: MAX_SEARCH_REQUESTS }
        fetch_counter = { count: 0, limit: MAX_FETCH_REQUESTS }
        web_search = Tools::WebSearch.new(@project, call_counter: search_counter)
        web_fetch = Tools::WebFetch.new(@project, call_counter: fetch_counter)

        chat = RubyLLM.chat(model: AGENT_MODEL, provider: AGENT_PROVIDER)
          .with_tools(web_search, web_fetch)
          .on_end_message do |message|
            @total_input_tokens += message.input_tokens.to_i
            @total_output_tokens += message.output_tokens.to_i
          end
          .on_tool_call do |tool_call|
            @nested_tool_count += 1
            nested_step = {
              type: "tool_call",
              n: @nested_tool_count,
              tool: tool_call.name,
              args: tool_call.arguments,
              timestamp: Time.current.iso8601
            }
            @step_callback&.call(nested_step)
            Rails.logger.info("[AiReviewer] [project:#{@project.id}] ResearchAssistant > ##{@nested_tool_count} #{tool_call.name}(#{tool_call.arguments.to_json.truncate(200)})")
          end
          .on_tool_result do |result|
            result_preview = result.to_s.truncate(500)
            nested_step = {
              type: "tool_result",
              n: @nested_tool_count,
              result: result_preview,
              timestamp: Time.current.iso8601
            }
            @step_callback&.call(nested_step)
            Rails.logger.info("[AiReviewer] [project:#{@project.id}] ResearchAssistant > │ result: #{result_preview.truncate(200)}")
          end

        chat.with_instructions(agent_system_prompt)

        response = Timeout.timeout(AGENT_TIMEOUT, nil, "Research assistant timed out after #{AGENT_TIMEOUT}s") do
          chat.ask(task)
        end

        # Track sub-tool costs
        @total_serp_cost += web_search.search_count * 0.0015

        summary = response.content.to_s.truncate(10_000)
        Rails.logger.info("[AiReviewer] [project:#{@project.id}] ResearchAssistant: completed (#{@nested_tool_count} tool calls, #{summary.length} chars)")

        @call_stats << {
          input_tokens: @total_input_tokens - prev_input,
          output_tokens: @total_output_tokens - prev_output,
          serp_cost: @total_serp_cost - prev_serp
        }

        summary
      rescue Timeout::Error => e
        Rails.logger.error("[AiReviewer] [project:#{@project.id}] ResearchAssistant error: #{e.message}")
        @total_serp_cost += web_search&.search_count.to_i * 0.0015 if web_search
        "Research assistant timed out. The task was: #{task.truncate(200)}"
      rescue StandardError => e
        Rails.logger.error("[AiReviewer] [project:#{@project.id}] ResearchAssistant error: #{e.message}")
        @total_serp_cost += web_search&.search_count.to_i * 0.0015 if web_search
        "Research assistant encountered an error. Try a different task."
      end

      private

      def agent_system_prompt
        <<~PROMPT
          You are a research assistant helping review a hardware project submission. Your job is to search the web and fetch URLs to gather information requested by the reviewer.

          You have two tools:
          - **WebSearch**: Search the web for information. Pass an array of `queries` to batch multiple searches in one call (max 5). Each query counts toward the search limit.
          - **WebFetch**: Fetch and read the text content from URLs. Pass an array of `urls` to batch multiple fetches in one call (max 3). Each URL counts toward the fetch limit.

          Guidelines:
          - You have a maximum of #{MAX_SEARCH_REQUESTS} web searches and #{MAX_FETCH_REQUESTS} page fetches per task. Each item in a batch counts individually toward these limits. Be strategic about how you use them.
          - Batch related searches or fetches into single calls when possible to reduce round trips.
          - Be thorough but efficient — search first, then fetch specific pages if needed. If the task can be answered with a web search result snippet, do not fetch the page.
          - Return a clear, concise summary of what you found
          - If a URL is dead or a product doesn't exist, say so clearly
          - Don't speculate — only report what you actually found
          - Keep your final answer focused on the reviewer's original question. Don't include unrelated information you found, and keep the wording concise. Prioritize word count over pretty grammar or complete sentences.
        PROMPT
      end
    end
  end
end
