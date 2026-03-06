module AiReviewer
  module Tools
    class QueryHardwareDocs < RubyLLM::Tool
      include AiReviewer::GithubClient

      DOCS_REPO = "qcoral/hardware-docs"
      DOCS_PATH = "site/src/content/docs"
      MAX_CONTENT_LENGTH = 15_000
      MAX_FILES_TO_READ = 5

      description "Search Hack Club's official hardware documentation for reference information about project requirements, submission guidelines, and hardware best practices."

      params do
        string :query, description: "What to search for in the hardware docs (e.g. 'BOM requirements', 'PCB guidelines', 'submission checklist')"
      end

      def initialize(project)
        @project = project
        super()
      end

      def execute(query:)
        Rails.logger.info("[AiReviewer] [project:#{@project.id}] Tool call: QueryHardwareDocs(#{query.truncate(100)})")

        doc_files = fetch_docs_tree
        return "Failed to fetch hardware docs tree." if doc_files.nil?
        return "No documentation files found." if doc_files.empty?

        keywords = query.downcase.split(/\s+/)

        scored_files = score_files(doc_files, keywords)
        matched_files = scored_files.select { |_path, score| score > 0 }
                                    .sort_by { |_path, score| -score }
                                    .first(MAX_FILES_TO_READ)
                                    .map(&:first)

        # Fallback: take first 3 files if no filename matches (likely index/overview docs)
        matched_files = doc_files.first(3) if matched_files.empty?

        results = fetch_and_search_content(matched_files, keywords)

        if results.empty?
          # No keyword matches in content — return full text of most relevant files
          results = fetch_full_content(matched_files)
        end

        format_results(results)
      rescue StandardError => e
        Rails.logger.error("[AiReviewer] [project:#{@project.id}] QueryHardwareDocs error: #{e.message}")
        "Error searching hardware docs."
      end

      private

      def fetch_docs_tree
        Rails.cache.fetch("hardware_docs_tree", expires_in: 1.hour) do
          response = github_fetch("/repos/#{DOCS_REPO}/git/trees/HEAD?recursive=1")
          next nil unless response.status == 200

          data = JSON.parse(response.body)
          tree = data["tree"] || []

          tree.filter_map do |item|
            next unless item["type"] == "blob"
            next unless item["path"].start_with?(DOCS_PATH)
            next unless item["path"].match?(/\.mdx?\z/)

            item["path"]
          end
        end
      end

      def score_files(doc_files, keywords)
        doc_files.map do |path|
          path_lower = path.downcase
          score = keywords.count { |kw| path_lower.include?(kw) }
          [ path, score ]
        end
      end

      def fetch_and_search_content(file_paths, keywords)
        sections = []

        file_paths.each do |file_path|
          content = fetch_file_content(file_path)
          next if content.nil?

          paragraphs = content.split(/\n{2,}/)
          matched_paragraphs = paragraphs.select do |para|
            para_lower = para.downcase
            keywords.any? { |kw| para_lower.include?(kw) }
          end

          next if matched_paragraphs.empty?

          sections << {
            path: file_path,
            content: matched_paragraphs.join("\n\n")
          }
        end

        sections
      end

      def fetch_full_content(file_paths)
        file_paths.filter_map do |file_path|
          content = fetch_file_content(file_path)
          next if content.nil?

          { path: file_path, content: content }
        end
      end

      def fetch_file_content(file_path)
        response = github_fetch("/repos/#{DOCS_REPO}/contents/#{file_path}")
        return nil unless response.status == 200

        data = JSON.parse(response.body)
        Base64.decode64(data["content"]).force_encoding("UTF-8")
      end

      def format_results(sections)
        output = []

        sections.each do |section|
          output << "## #{section[:path]}\n\n#{section[:content]}"
        end

        result = output.join("\n\n---\n\n")
        result.truncate(MAX_CONTENT_LENGTH)
      end
    end
  end
end
