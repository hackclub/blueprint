class ProjectAirtableUploadJob < ApplicationJob
  queue_as :background

  # Uploads a project's review data to Airtable out of band. This makes a blocking
  # external HTTP call (Airtable + Identity Vault), so it must never run inside a
  # web request — doing so previously timed out the build approval / promote flow.
  def perform(project_id)
    project = Project.find_by(id: project_id)
    return unless project

    project.upload_to_airtable!
  rescue => e
    Rails.logger.tagged("ProjectAirtableUploadJob") do
      Rails.logger.error("Failed to upload project #{project_id} to Airtable: #{e.message}")
    end
    Sentry.capture_exception(e)
    raise
  end
end
