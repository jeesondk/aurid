# Rails Helper for RSpec
# This file is loaded by spec_helper

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"

# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"
require "factory_bot_rails"
require "faker"
require "shoulda/matchers"
require "timecop"
require "webmock/rspec"
require "vcr"

# Require all factories
Dir[Rails.root.join("spec/factories/**/*.rb")].sort.each { |f| require f }

# Require all support files
Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |f| require f }

# Checks for pending migrations and applies them before tests.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  puts e.to_s.strip
  exit 1
end

# Configure Shoulda Matchers for Rails
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

# Configure FactoryBot
FactoryBot::SyntaxRunner.send(:include, FactoryBot::Syntax::Methods)

# Configure DatabaseCleaner
require "database_cleaner-active_record"

RSpec.configure do |config|
  # Use DatabaseCleaner to clean the database between tests
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  # Use transactional fixtures for JavaScript tests
  config.use_transactional_fixtures = true

  # Filter out Rails' own gems from backtraces
  config.filter_rails_from_backtrace!

  # Add custom filters
  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  # Run specs in random order
  config.order = :random
  Kernel.srand config.seed

  # Enable full backtrace
  config.full_backtrace = true

  # Color output
  config.color = true
  config.formatter = :documentation

  # Fail fast
  config.fail_fast = ENV["FAIL_FAST"] == "true"

  # Include Devise test helpers
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::ControllerHelpers, type: :view
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :feature
  config.include Warden::Test::Helpers

  # Configure Capybara
  config.before(:each, type: :feature) do
    # Switch to cuprite driver for JavaScript tests
    Capybara.current_driver = :cuprite
  end

  config.after(:each, type: :feature) do
    # Reset driver
    Capybara.use_default_driver
  end

  # Configure for API tests
  config.before(:each, type: :api) do
    request.accept = "application/json"
  end
end

# Custom RSpec matchers
RSpec::Matchers.define :have_http_status do |expected|
  match do |actual|
    actual.is_a?(ActionDispatch::Response) && actual.status == expected
  end
  
  failure_message do |actual|
    "expected HTTP status to be #{expected} but got #{actual.status}"
  end
  
  failure_message_when_negated do |actual|
    "expected HTTP status not to be #{expected}"
  end
end

RSpec::Matchers.define :be_json do
  match do |actual|
    actual.is_a?(String) && JSON.parse(actual).is_a?(Hash)
  rescue JSON::ParserError
    false
  end
  
  failure_message do |actual|
    "expected #{actual.inspect} to be valid JSON"
  end
end

RSpec::Matchers.define :have_json_key do |expected_key|
  match do |actual|
    actual.is_a?(String) && JSON.parse(actual).key?(expected_key)
  rescue JSON::ParserError
    false
  end
  
  failure_message do |actual|
    "expected JSON to have key '#{expected_key}'"
  end
end

RSpec::Matchers.define :have_json_keys do |*expected_keys|
  match do |actual|
    actual.is_a?(String) && 
      expected_keys.all? { |key| JSON.parse(actual).key?(key) }
  rescue JSON::ParserError
    false
  end
  
  failure_message do |actual|
    missing = expected_keys.reject { |key| JSON.parse(actual).key?(key) rescue false }
    "expected JSON to have keys: #{missing.join(', ')}"
  end
end

# Test data generators
module TestData
  module_function

  def random_email
    Faker::Internet.safe_email
  end

  def random_password(length = 12)
    Faker::Internet.password(min_length: length, max_length: length)
  end

  def random_uuid
    SecureRandom.uuid
  end

  def random_tenant_name
    "#{Faker::Company.name.gsub(/[^a-zA-Z0-9]/, '')}#{rand(1000)}"
  end

  def random_domain
    "#{Faker::Internet.domain_name}.com"
  end

  def random_first_name
    Faker::Name.first_name
  end

  def random_last_name
    Faker::Name.last_name
  end
end
