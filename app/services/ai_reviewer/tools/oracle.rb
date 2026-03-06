module AiReviewer
  module Tools
    class Oracle < RubyLLM::Tool
      description "Ask a more powerful AI model (Claude 3.5 Haiku) a specific question when you need deeper analysis or reasoning. Use sparingly — only for complex technical questions about hardware design, PCB layout, firmware architecture, or CAD that require expert knowledge. You MUST include all relevant context in your question since the oracle has no access to the project."

      ORACLE_MODEL = "anthropic/claude-3.5-haiku"
      ORACLE_TIMEOUT = 300

      params do
        string :question, description: "The specific question to ask, including all necessary context. The oracle cannot see the project — you must provide everything it needs."
      end

      attr_reader :total_input_tokens, :total_output_tokens, :call_stats

      def initialize(project)
        @project = project
        @total_input_tokens = 0
        @total_output_tokens = 0
        @call_stats = []
        super()
      end

      def execute(question:)
        Rails.logger.info("[AiReviewer] [project:#{@project.id}] Tool call: Oracle(#{question.truncate(200)})")

        chat = RubyLLM.chat(model: ORACLE_MODEL, provider: :openrouter)
        chat.with_instructions("You are a technical expert assistant specializing in hardware engineering, PCB design, embedded systems, and CAD. Answer concisely and precisely. Focus on factual, actionable information.")
        response = Timeout.timeout(ORACLE_TIMEOUT) { chat.ask(question) }

        @total_input_tokens += response.input_tokens.to_i
        @total_output_tokens += response.output_tokens.to_i
        @call_stats << { input_tokens: response.input_tokens.to_i, output_tokens: response.output_tokens.to_i }
        Rails.logger.info("[AiReviewer] [project:#{@project.id}] Oracle: #{response.input_tokens} in + #{response.output_tokens} out tokens")

        "Oracle response:\n\n#{response.content.to_s.truncate(5000)}"
      rescue Timeout::Error
        Rails.logger.error("[AiReviewer] [project:#{@project.id}] Oracle error: Timed out after #{ORACLE_TIMEOUT}s")
        "Oracle timed out after #{ORACLE_TIMEOUT}s"
      rescue StandardError => e
        Rails.logger.error("[AiReviewer] [project:#{@project.id}] Oracle error: #{e.message}")
        "Oracle encountered an error. Try rephrasing your question."
      end
    end
  end
end
