module AiReviewer
  module Tools
    class QueryBlueprintDocs < RubyLLM::Tool
      DOCS_DIR = Rails.root.join("docs")
      MAX_CONTENT_LENGTH = 15_000
      MAX_FILES_TO_READ = 5

      description "Search Blueprint's own documentation for submission requirements, shipping guidelines, parts sourcing advice, and project guidelines. Key docs: submission-guidelines.md (bare minimum requirements), shipping.md (shipping philosophy), parts-sourcing.md (sourcing tips), bom.md (BOM format), project-guidelines.md (project rules)."

      params do
        string :query, description: "What to search for in the Blueprint docs (e.g. 'submission requirements', 'shipping', 'parts sourcing', 'BOM format')"
      end

      def initialize(project)
        @project = project
        super()
      end

      def execute(query:)
        Rails.logger.info("[AiReviewer] [project:#{@project.id}] Tool call: QueryBlueprintDocs(#{query.truncate(100)})")

        doc_files = find_doc_files
        return "No documentation files found." if doc_files.empty?

        keywords = query.downcase.split(/\s+/)

        scored_files = score_files(doc_files, keywords)
        matched_files = scored_files.select { |_path, score| score > 0 }
                                    .sort_by { |_path, score| -score }
                                    .first(MAX_FILES_TO_READ)
                                    .map(&:first)

        matched_files = doc_files.first(3) if matched_files.empty?

        results = fetch_and_search_content(matched_files, keywords)

        if results.empty?
          results = fetch_full_content(matched_files)
        end

        format_results(results)
      rescue StandardError => e
        Rails.logger.error("[AiReviewer] [project:#{@project.id}] QueryBlueprintDocs error: #{e.message}")
        "Error searching blueprint docs."
      end

      private

      def find_doc_files
        Dir.glob(DOCS_DIR.join("**/*.md")).map do |path|
          Pathname.new(path).relative_path_from(DOCS_DIR).to_s
        end.reject { |path| path == "ai_reviewer_guide.md" }
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
          content = read_file(file_path)
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
          content = read_file(file_path)
          next if content.nil?

          { path: file_path, content: content }
        end
      end

      def read_file(relative_path)
        full_path = DOCS_DIR.join(relative_path)
        return nil unless full_path.exist?

        full_path.read.force_encoding("UTF-8")
      end

      def format_results(sections)
        output = sections.map do |section|
          "## #{section[:path]}\n\n#{section[:content]}"
        end

        result = output.join("\n\n---\n\n")
        result.truncate(MAX_CONTENT_LENGTH)
      end
    end
  end
end
