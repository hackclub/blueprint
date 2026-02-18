module AiReviewer
  module Tools
    class GetJournal < RubyLLM::Tool
      description "Get the full project journal. Returns all journal entries as markdown, each with its duration in hours, summary, date, and full content."

      def initialize(project)
        @project = project
        super()
      end

      def execute
        Rails.logger.info("[AiReviewer] [project:#{@project.id}] Tool call: GetJournal")
        entries = @project.journal_entries.order(created_at: :asc)
        if entries.empty?
          Rails.logger.info("[AiReviewer] [project:#{@project.id}] GetJournal: no entries found")
          return "No journal entries found."
        end

        lines = []
        total_hours = (entries.sum(:duration_seconds) / 3600.0).round(2)
        lines << "# Journal — #{entries.count} entries, #{total_hours} total hours\n"

        entries.each_with_index do |entry, i|
          hours = (entry.duration_seconds / 3600.0).round(2)
          lines << "## Entry #{i + 1}: #{entry.summary} (#{hours}h) — #{entry.created_at.strftime('%Y-%m-%d')}"
          lines << entry.content.to_s
          lines << ""
        end

        result = lines.join("\n").truncate(50_000)
        Rails.logger.info("[AiReviewer] [project:#{@project.id}] GetJournal: returned #{entries.count} entries, #{total_hours}h total (#{result.length} chars)")
        result
      end
    end
  end
end
