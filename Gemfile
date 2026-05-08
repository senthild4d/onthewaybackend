source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.2", ">= 8.0.2.1"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# JWT for token-based authentication
gem "jwt"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# Required for video thumbnails (preview resize) and image variants
gem "image_processing", "~> 1.2"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
gem "rack-cors"

# QR Code generation
gem "rqrcode"
gem "chunky_png"

# Payment providers
gem "stripe"
gem "paypal-sdk-rest"
gem "sendgrid-ruby"
gem "twilio-ruby"
gem "dotenv-rails"

# Firebase Cloud Messaging (push notifications)
gem "fcm"

# ActionCable production pub/sub (config/cable.yml uses adapter: redis)
gem "redis"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
  
  # Testing framework
  gem "rspec-rails", "~> 6.0"
  
  # Test data factories
  gem "factory_bot_rails", "~> 6.4"
  
  # Fake data generation
  gem "faker", "~> 3.2"
  
  # Debugging
  gem "pry-rails"
  gem "pry-byebug"
end

group :test do
  # Database cleaning
  gem "database_cleaner-active_record", "~> 2.1"
  
  # Additional matchers for RSpec
  gem "shoulda-matchers", "~> 5.3"
  
  # Code coverage
  gem "simplecov", require: false
  
  # Request mocking (for external APIs)
  gem "webmock", "~> 3.19"
  gem "vcr", "~> 6.2"
end
