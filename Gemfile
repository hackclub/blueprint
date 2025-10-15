source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.3"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use sqlite3 as the database for Active Record
gem "sqlite3", ">= 2.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Dashboard for jobs
gem "mission_control-jobs"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

gem "aws-sdk-s3", require: false

gem "tailwindcss-rails", "~> 4.0"

# Redis for cache, queue, and Action Cable
gem "redis", "~> 5.0"

# PostgreSQL adapter for ActiveRecord
gem "pg", "~> 1.6"

# GitHub-style Markdown editor for Rails
gem "marksmith"

# HTTP client
gem "faraday", "~> 2.14"

# Slack client
gem "slack-ruby-client", "~> 3.0"

# Inline SVG support
gem "inline_svg"

# Skylight for performance monitoring
gem "skylight"

# Sentry for error tracking
gem "sentry-ruby"
gem "sentry-rails"

# PaperTrail for audit logging
gem "paper_trail"

# Pagination
gem "pagy"

# Flipper for feature flags
gem "flipper"
gem "flipper-active_record"
gem "flipper-ui"

gem "tailwind_merge", "~> 1.3"

gem "redcarpet"

gem "blazer"

gem "ahoy_matey"

gem "disco"

gem "jwt"

gem "chartkick"

gem "lz_string"

gem "rack-attack"

gem "active_storage_validations"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  gem "erb_lint", require: false

  gem "dotenv-rails"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Annotate Rails classes with schema information
  gem "annotaterb"

  # For detecting N+1 queries and unused eager loading
  gem "bullet"

  # Live reload for Hotwire
  gem "hotwire-livereload", "~> 2.1"

  gem "pre-commit", require: false

  gem "execjs", require: false
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"

  # Headless Chrome driver
  gem "selenium-webdriver"
end
