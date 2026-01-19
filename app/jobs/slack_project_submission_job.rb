class SlackProjectSubmissionJob < ApplicationJob
  queue_as :default

  CHANNEL_ID = "C09SJ2R1002".freeze
  SLACK_HAZARDOUS_PATTERNS = [
    /<!channel>/i,
    /<!here>/i,
    /<!everyone>/i,
    /@channel\b/i,
    /@here\b/i,
    /@everyone\b/i
  ].freeze

  def perform(project_id)
    project = Project.find_by(id: project_id)
    return unless project

    client = Slack::Web::Client.new(token: ENV.fetch("SLACK_BLUEY_TOKEN", nil))

    project_url = "https://#{ENV.fetch('APPLICATION_HOST')}/projects/#{project.id}"
    author_mention = project.user&.slack_id.present? ? "<@#{project.user.slack_id}>" : project.user&.display_name || "Unknown"
    sanitized_title = sanitize_slack_text(project.title)
    sanitized_description = sanitize_slack_text(project.description).truncate(500)

    blocks = [
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*#{sanitized_title}*"
        }
      },
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: sanitized_description
        }
      },
            {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*<#{project_url}|Blueprint> | <#{project.repo_link}|GitHub>*"
        }
      }
    ]

    if project.display_banner.present?
      image_url = Rails.application.routes.url_helpers.rails_blob_url(
        project.display_banner,
        host: ENV.fetch("APPLICATION_HOST")
      )
      blocks << {
        type: "image",
        image_url: image_url,
        alt_text: project.title || "Project image"
      }
    end

    message_options = {
      channel: CHANNEL_ID,
      blocks: blocks
    }

    if project.user.present?
      message_options[:username] = project.user.display_name
      message_options[:icon_url] = project.user.avatar if project.user.avatar.present?
    end

    response = client.chat_postMessage(message_options)

    if response.ok && response.ts.present?
      message_url = "https://hackclub.slack.com/archives/#{CHANNEL_ID}/p#{response.ts.to_s.delete('.')}"
      project.update_column(:slack_message, message_url)
    end
  rescue StandardError => e
    Rails.logger.tagged("SlackProjectSubmissionJob") do
      Rails.logger.error({ event: "slack_project_submission_failed", project_id: project_id, error: e.message }.to_json)
    end
    raise e
  end

  private

  def sanitize_slack_text(text)
    return "" if text.blank?

    SLACK_HAZARDOUS_PATTERNS.reduce(text.to_s) { |result, pattern| result.gsub(pattern, "") }
  end
end
