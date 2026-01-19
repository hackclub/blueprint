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
    # disable in dev
    return if Rails.env.development?

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
          text: "*#{sanitized_title.presence || 'Untitled Project'}*"
        }
      }
    ]

    if sanitized_description.present?
      blocks << {
        type: "section",
        text: {
          type: "mrkdwn",
          text: sanitized_description
        }
      }
    end

    links = [ "<#{project_url}|Blueprint>" ]
    links << "<#{project.repo_link}|GitHub>" if project.repo_link.present?

    blocks << {
      type: "section",
      text: {
        type: "mrkdwn",
        text: "*#{links.join(' | ')} | #{author_mention}*"
      }
    }

    host = ENV.fetch("APPLICATION_HOST")
    if project.display_banner.present? && !host.include?("localhost")
      image_url = Rails.application.routes.url_helpers.rails_blob_url(
        project.display_banner,
        host: host
      )
      blocks << {
        type: "image",
        image_url: image_url,
        alt_text: project.title || "Project image"
      }
    end

    message_options = {
      channel: CHANNEL_ID,
      blocks: blocks,
      unfurl_links: false,
      unfurl_media: false
    }

    if project.user.present?
      message_options[:username] = project.user.display_name
      message_options[:icon_url] = project.user.avatar if project.user.avatar.present?
    end

    Rails.logger.info({ event: "slack_project_submission_debug", blocks: blocks.to_json }.to_json)
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
