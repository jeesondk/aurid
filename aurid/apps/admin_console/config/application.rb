require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module AdminConsole
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do not contain
    # .rb files, or that should not be eager-loaded such as `templates` or `generators`.
    # The `lib` directory contains our service objects and other business logic
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environment files.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    # Set application name
    config.application_name = "Aurid Admin Console"

    # Time zone
    config.time_zone = "Copenhagen"

    # Locale
    config.i18n.default_locale = :en
    config.i18n.available_locales = [:en, :da, :de, :fr]
    config.i18n.fallbacks = [I18n.default_locale]

    # Generators
    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
      g.test_framework :rspec, fixture: false, views: false
      g.fixture_replacement :factory_bot, dir: "spec/factories"
      g.helper false
      g.assets false
      g.stylesheets false
      g.javascripts false
    end

    # Use UUID as primary key
    config.generators.orm :active_record, primary_key_type: :uuid

    # Active Record configuration
    config.active_record.default_timezone = :utc
    config.active_record.schema_format = :sql

    # Cache configuration
    config.cache_store = :redis_cache_store, {
      url: ENV.fetch("REDIS_CACHE_URL") { "redis://localhost:6379/1" },
      namespace: "admin_console_cache"
    }

    # Session store
    config.session_store :redis_session_store, {
      redis: {
        expires_in: 1.day,
        key_prefix: "aurid_admin_console:sessions",
        url: ENV.fetch("REDIS_SESSION_URL") { "redis://localhost:6379/2" }
      }
    }

    # Action Mailer configuration
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: ENV.fetch("SMTP_ADDRESS") { "localhost" },
      port: ENV.fetch("SMTP_PORT") { 587 },
      domain: ENV.fetch("SMTP_DOMAIN") { "aurid.io" },
      authentication: :plain,
      user_name: ENV["SMTP_USERNAME"],
      password: ENV["SMTP_PASSWORD"],
      enable_starttls_auto: true
    }

    # Asset pipeline
    config.assets.enabled = true
    config.assets.css_compressor = :sass
    config.assets.js_compressor = :terser

    # Hotwire/Turbo configuration
    config.importmap.cache_sweepers << Rails.root.join("app/views")

    # Security configuration
    config.action_controller.default_protect_from_forgery = true
    config.action_controller.allow_forgery_protection = true

    # CORS configuration for API endpoints
    config.action_controller.forgery_protection_origin_check = false

    # Health check endpoint
    config.health_check = ActiveSupport::OrderedOptions.new
    config.health_check.path = "/health"
    config.health_check.max_age = 1

    # Sidekiq configuration
    config.active_job.queue_adapter = :sidekiq

    # Flipper configuration
    config.flipper = ActiveSupport::OrderedOptions.new
    config.flipper.adapter = :active_record
    config.flipper.preload = true

    # Administrate configuration
    config.administrate = ActiveSupport::OrderedOptions.new
    config.administrate.fields = {
      json: Administrate::Field::JSON,
      nested_has_many: Administrate::Field::NestedHasMany
    }

    # Keycloak configuration
    config.keycloak = ActiveSupport::OrderedOptions.new
    config.keycloak.url = ENV.fetch("KEYCLOAK_URL") { "http://localhost:8080" }
    config.keycloak.realm = ENV.fetch("KEYCLOAK_REALM") { "aurid" }
    config.keycloak.client_id = ENV.fetch("KEYCLOAK_CLIENT_ID") { "admin-console" }
    config.keycloak.client_secret = ENV["KEYCLOAK_CLIENT_SECRET"]
    config.keycloak.admin_username = ENV["KEYCLOAK_ADMIN_USERNAME"]
    config.keycloak.admin_password = ENV["KEYCLOAK_ADMIN_PASSWORD"]

    # FreeIPA configuration
    config.freeipa = ActiveSupport::OrderedOptions.new
    config.freeipa.server = ENV.fetch("FREEIPA_SERVER") { "ipa.aurid.io" }
    config.freeipa.username = ENV["FREEIPA_USERNAME"]
    config.freeipa.password = ENV["FREEIPA_PASSWORD"]
    config.freeipa.basedn = ENV.fetch("FREEIPA_BASEDN") { "dc=aurid,dc=io" }

    # Control Plane API configuration
    config.control_plane = ActiveSupport::OrderedOptions.new
    config.control_plane.url = ENV.fetch("CONTROL_PLANE_URL") { "http://localhost:3001" }
    config.control_plane.api_key = ENV["CONTROL_PLANE_API_KEY"]

    # Logging configuration
    config.logger = ActiveSupport::Logger.new(STDOUT)
    config.logger.formatter = proc do |severity, timestamp, progname, msg|
      "[#{timestamp.to_formatted_s(:db)}] [#{severity}] [#{Process.pid}] #{msg}\n"
    end

    # Error tracking
    config.sentry_dsn = ENV["SENTRY_DSN"]
    config.sentry_environment = ENV.fetch("SENTRY_ENVIRONMENT") { Rails.env }

    # Metrics
    config.prometheus_enabled = ENV.fetch("PROMETHEUS_ENABLED", "false") == "true"

    # Feature flags
    config.feature_flags = {
      audit_logging: ENV.fetch("FEATURE_AUDIT_LOGGING", "true") == "true",
      ad_migration: ENV.fetch("FEATURE_AD_MIGRATION", "true") == "true",
      multi_tenant: ENV.fetch("FEATURE_MULTI_TENANT", "true") == "true"
    }
  end
end

# Load application configuration
Rails.application.configure do
  # Additional configuration can go here
end
