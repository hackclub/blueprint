class GithubJournalSyncJob < ApplicationJob
  queue_as :default

  def perform(project_id)
    project = Project.find_by(id: project_id)
    user = project&.user

    unless project && user && user.github_user? && project.repo_link.present?
      Rails.logger.tagged("GithubJournalSyncJob") do
        Rails.logger.error({ event: "project_cannot_sync", project_id: project_id }.to_json)
      end
      raise StandardError, "Project cannot be synced"
      nil
    end

    content = project.generate_journal(false)

    begin
      org, repo = project.parse_repo.values_at(:org, :repo_name)
      get_response = user.fetch_github("/repos/#{org}/#{repo}/contents/JOURNAL.md")

      if get_response.status == 200
        result = JSON.parse(get_response.body)
        sha = result["sha"]
      else
        Rails.logger.tagged("GithubJournalSyncJob") do
          Rails.logger.info({ event: "journal_not_found", project_id: project_id, status: get_response.status }.to_json)
        end
      end

      put_response = user.fetch_github(
        "/repos/#{org}/#{repo}/contents/JOURNAL.md",
        method: :put,
        data: { message: "Update JOURNAL.md", content: Base64.strict_encode64(content), sha: sha }.compact,
        headers: { "Content-Type" => "application/json" }
      )

      if put_response.status.in?([ 200, 201 ])
        Rails.logger.tagged("GithubJournalSyncJob") do
          Rails.logger.info({ event: "journal_synced", project_id: project_id, status: put_response.status }.to_json)
        end
      else
        error_body = put_response.body
        error_data = {
          event: "journal_sync_failed",
          project_id: project_id,
          status: put_response.status,
          response_body: error_body,
          org: org,
          repo: repo,
          user_id: user.id,
          content_size: content.bytesize,
          sha_present: sha.present?
        }

        Rails.logger.tagged("GithubJournalSyncJob") do
          Rails.logger.error(error_data.to_json)
        end

        Sentry.capture_message("Failed to sync journal to GitHub", level: :error, extra: error_data)
        raise StandardError, "Failed to sync journal: #{put_response.status}"
      end
    rescue StandardError => e
      error_data = {
        event: "journal_sync_exception",
        project_id: project_id,
        error_class: e.class.name,
        error_message: e.message,
        backtrace: e.backtrace&.first(10),
        user_id: user&.id,
        org: org,
        repo: repo
      }

      Rails.logger.tagged("GithubJournalSyncJob") do
        Rails.logger.error(error_data.to_json)
      end

      Sentry.capture_exception(e, extra: error_data)
      raise
    end
  end
end
