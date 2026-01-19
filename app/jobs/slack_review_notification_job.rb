class SlackReviewNotificationJob < ApplicationJob
  queue_as :default

  SLACK_HAZARDOUS_PATTERNS = [
    /<!channel>/i,
    /<!here>/i,
    /<!everyone>/i,
    /@channel\b/i,
    /@here\b/i,
    /@everyone\b/i
  ].freeze

  def perform(review_type, review_id)
    review = review_type.constantize.find_by(id: review_id)
    return unless review
    return unless review.feedback.present?

    project = review.project
    return unless project&.slack_message.present?

    thread_ts = extract_thread_ts(project.slack_message)
    return unless thread_ts

    client = Slack::Web::Client.new(token: ENV.fetch("SLACK_BLUEY_TOKEN", nil))
    channel_id = extract_channel_id(project.slack_message)

    sanitized_feedback = sanitize_slack_text(review.feedback)
    review_type_label = review_type == "DesignReview" ? "design" : "build"
    result_message = review.result == "approved" ? "APPROVED!! :D" : "needs update"

    blocks = [
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "_#{review_type_label} review - #{result_message}_"
        }
      },
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: sanitized_feedback
        }
      }
    ]

    message_options = {
      channel: channel_id,
      thread_ts: thread_ts,
      blocks: blocks
    }

    if review.reviewer.present?
      message_options[:username] = review.reviewer.display_name
      message_options[:icon_url] = review.reviewer.avatar if review.reviewer.avatar.present?
    end

    client.chat_postMessage(message_options)
  rescue StandardError => e
    Rails.logger.tagged("SlackReviewNotificationJob") do
      Rails.logger.error({ event: "slack_review_notification_failed", review_type: review_type, review_id: review_id, error: e.message }.to_json)
    end
    raise e
  end

  private

  def extract_thread_ts(slack_message_url)
    match = slack_message_url.match(/\/p(\d+)$/)
    return unless match

    raw_ts = match[1]
    "#{raw_ts[0..9]}.#{raw_ts[10..]}"
  end

  def extract_channel_id(slack_message_url)
    match = slack_message_url.match(/archives\/([A-Z0-9]+)\//)
    match[1] if match
  end

  def sanitize_slack_text(text)
    return "" if text.blank?

    SLACK_HAZARDOUS_PATTERNS.reduce(text.to_s) { |result, pattern| result.gsub(pattern, "") }
  end
end
