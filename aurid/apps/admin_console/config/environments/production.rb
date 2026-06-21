# Admin Console production environment configuration
Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks, however, may not work as expected and we disable them.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # In production, you should configure your web server to serve static assets
  # instead of relying on Rails to do it.
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?

  # Compress JavaScripts and CSS.
  config.assets.js_compressor = :terser
  config.assets.css_compressor = :sass

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  config.public_file_server.enabled = true

  # Enable asset digests for fingerprinting
  config.assets.digest = true

  # `config.assets.precompile` and `config.assets.version` are set in config/initializers/assets.rb

  # Specifies the header that your server uses for sending files.
  # config.public_file_server.headers = {
  #   'Cache-Control' => 'public, max-age=3600'
  # }

  # Force all access to the app over SSL, use Strict-Transport-Security,
  # and use secure cookies.
  config.force_ssl = ENV.fetch("FORCE_SSL", "true") == "true"

  # Use the lowest log level to ensure availability of diagnostic information.
  # When using the "json" log format, the log level can be set to :debug to
  # log all deprecation notices and other diagnostic information to the logs.
  config.log_level = ENV.fetch("LOG_LEVEL", "info").to_sym

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # Use a different cache store in production.
  config.cache_store = :redis_cache_store, {
    url: ENV.fetch("REDIS_CACHE_URL") { "redis://redis.aurid.io:6379/1" },
    namespace: "admin_console_cache",
    expires_in: 1.hour,
    compress: true,
    pool_size: 5,
    pool_timeout: 5
  }

  # Use a real queuing backend for Active Job (and separate queues per environment)
  # config.active_job.queue_adapter = :resque
  # config.active_job.queue_name_prefix = "aurid_admin_console_#{Rails.env}"
  config.active_job.queue_adapter = :sidekiq

  # Store uploaded files on S3 (or compatible storage)
  # config.active_storage.service = :amazon

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.logger = ActiveSupport::Logger.new(STDOUT)
  config.logger.formatter = proc do |severity, timestamp, progname, msg|
    "[#{timestamp.to_formatted_s(:db)}] [#{severity}] [#{Process.pid}] #{msg}\n"
  end

  # Use a different logger for Sidekiq
  if defined?(Sidekiq)
    Sidekiq::Logging.logger = Rails.logger
  end

  # Use a real queuing backend for Active Storage.
  # config.active_storage.queues.analysis = :low
  # config.active_storage.queues.purge = :low

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Inserts middleware to perform automatic connection switching.
  # The `database_selector` gem is required (and only in Gemfile, not in application.rb).
  # config.middleware.use DatabaseSelector::Middleware

  # Ensure requests are idempotent by filtering out parameters that are
  # known to cause issues with caching.
  # config.action_controller.param_encoders = [ :json ]

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = false

  # Raises error for missing translations
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = false

  # Use default privacy policy (see https://guides.rubyonrails.org/security.html#security-headers)
  # config.action_dispatch.default_headers = {
  #   'X-Frame-Options' => 'SAMEORIGIN',
  #   'X-XSS-Protection' => '1; mode=block',
  #   'X-Content-Type-Options' => 'nosniff',
  #   'X-Permitted-Cross-Domain-Policies' => 'none',
  #   'Referrer-Policy' => 'strict-origin-when-cross-origin'
  # }

  # Security headers
  config.action_dispatch.default_headers = {
    "X-Frame-Options" => "DENY",
    "X-Content-Type-Options" => "nosniff",
    "X-XSS-Protection" => "1; mode=block",
    "Referrer-Policy" => "strict-origin-when-cross-origin",
    "Content-Security-Policy" => "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; frame-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'"
  }

  # CORS configuration
  config.action_controller.forgery_protection_origin_check = true

  # Action Mailer configuration for production
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV.fetch("SMTP_ADDRESS") { "smtp.aurid.io" },
    port: ENV.fetch("SMTP_PORT") { 587 },
    domain: ENV.fetch("SMTP_DOMAIN") { "aurid.io" },
    authentication: :plain,
    user_name: ENV["SMTP_USERNAME"],
    password: ENV["SMTP_PASSWORD"],
    enable_starttls_auto: true
  }
  config.action_mailer.perform_caching = false
  config.action_mailer.raise_delivery_errors = true

  # Error tracking configuration
  if ENV["SENTRY_DSN"].present?
    Sentry.init do |config|
      config.dsn = ENV["SENTRY_DSN"]
      config.breadcrumbs_logger = [:active_support_logger, :http_logger]
      config.environment = ENV.fetch("SENTRY_ENVIRONMENT") { Rails.env }
      config.release = ENV.fetch("SENTRY_RELEASE") { `git rev-parse HEAD`.chomp }
      config.send_default_pii = false
      config.traces_sample_rate = 0.1
      config.profiles_sample_rate = 0.01
    end
  end

  # Prometheus metrics
  if ENV.fetch("PROMETHEUS_ENABLED", "false") == "true"
    require "prometheus_exporter/middleware"
    Rails.application.middleware.use PrometheusExporter::Middleware
  end

  # Health check configuration
  config.health_check = ActiveSupport::OrderedOptions.new
  config.health_check.path = "/health"
  config.health_check.max_age = 1

  # Session store configuration
  config.session_store :redis_session_store, {
    redis: {
      expires_in: 1.day,
      key_prefix: "aurid_admin_console:sessions",
      url: ENV.fetch("REDIS_SESSION_URL") { "redis://redis.aurid.io:6379/2" },
      pool_size: 5,
      pool_timeout: 5
    }
  }

  # Cache configuration
  config.cache_store = :redis_cache_store, {
    url: ENV.fetch("REDIS_CACHE_URL") { "redis://redis.aurid.io:6379/1" },
    namespace: "admin_console_cache",
    expires_in: 1.hour,
    compress: true,
    pool_size: 5,
    pool_timeout: 5
  }
end
