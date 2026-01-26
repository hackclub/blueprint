FerrumPdf.configure do |config|
  if Rails.env.production?
    config.browser_path = ENV.fetch("CHROMIUM_PATH", "/usr/bin/chromium")
    config.browser_options = { "no-sandbox" => nil }
  end
end
