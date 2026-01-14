module ApplicationHelper
  include Pagy::Frontend

  def admin_namespace?
    controller_path.start_with?("admin/")
  end

  # Shorthand helper for merging Tailwind class strings in views.
  # Accepts strings/arrays/nil values, just like Tailwind.merge.
  def tw(*classes)
    Tailwind.merge(*classes)
  end

  def safe_path(url)
    return nil if url.blank?
    uri = URI.parse(url)
    return nil unless uri.scheme.nil? && uri.host.nil? && uri.path.present? && uri.path.start_with?("/")
    uri.path + (uri.query.present? ? "?#{uri.query}" : "")
  rescue URI::InvalidURIError
    nil
  end

  def c_time_ago_in_words(time, include_seconds: false)
    data_attrs = { controller: "time-ago" }
    data_attrs[:"time-ago-include-seconds-value"] = true if include_seconds

    content_tag :time, time.strftime("%-m/%-d/%Y at %-I:%M %p"), datetime: time.iso8601, data: data_attrs
  end

  def hca_signup_url
    "#{IdentityVaultService.host}signup"
  end
end
