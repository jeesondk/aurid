# RSpec configuration for Admin Console
# This file is copied to spec/ when you run 'rails generate rspec:install'

require "rails_helper"

# Require all support files
Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |f| require f }

# Configure RSpec
RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  # Run specs in random order to surface order dependencies
  config.order = :random
  Kernel.srand config.seed

  # Seed global randomization in this process using the `--seed` CLI option
  config.global_fixtures = :all

  # Filter lines from backtraces
  config.backtrace_exclusion_patterns << /\/gems\//
  config.backtrace_exclusion_patterns << /_delivered\//
  config.backtrace_exclusion_patterns << /lib\/rails\//
  config.backtrace_exclusion_patterns << /lib\/ruby\//
  config.backtrace_exclusion_patterns << /bin\//
  config.backtrace_exclusion_patterns << /spec\//

  # Color output
  config.color = true
  config.formatter = :documentation

  # Fail fast on first failure (can be overridden with --fail-fast false)
  config.fail_fast = ENV["FAIL_FAST"] == "true"

  # Show full backtrace on failure
  config.full_backtrace = true

  # Use transactional fixtures
  config.use_transactional_fixtures = true

  # Filter gems from backtrace
  config.filter_gems_from_backtrace "rails", "rspec", "factory_bot", "faker", "shoulda"

  # Include FactoryBot syntax
  config.include FactoryBot::Syntax::Methods

  # Configure Shoulda Matchers
  Shoulda::Matchers.configure do |shoulda_config|
    shoulda_config.integrate do |with|
      with.test_framework :rspec
      with.library :rails
    end
  end

  # Configure Timecop for time travel testing
  config.before(:suite) do
    Timecop.safe_mode = true
  end

  config.after(:each) do
    Timecop.return
  end

  # Configure VCR for HTTP request testing
  VCR.configure do |vcr_config|
    vcr_config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
    vcr_config.hook_into :webmock
    vcr_config.configure_rspec_metadata!
    vcr_config.ignore_localhost = true
    vcr_config.ignore_hosts "127.0.0.1", "localhost"
    vcr_config.default_cassette_options = {
      record: :new_episodes,
      match_requests_on: [:method, :uri, :body],
      re_record_interval: 7.days
    }
  end

  # Configure WebMock
  WebMock.disable_net_connect!(allow_localhost: true, allow: ["chromedriver.storage.googleapis.com"])

  # Configure Capybara
  Capybara.register_driver(:cuprite) do |app|
    Capybara::Cuprite::Driver.new(app, {
      browser_options: { 'no-sandbox' => nil },
      inspector: true,
      headless: !ENV["CAPYBARA_VISIBLE"]
    })
  end
  Capybara.javascript_driver = :cuprite
  Capybara.default_max_wait_time = 10

  # Configure SimpleCov for test coverage
  if ENV["COVERAGE"] == "true"
    require "simplecov"
    SimpleCov.start "rails" do
      add_filter "/config/"
      add_filter "/spec/"
      add_filter "/lib/tasks/"
      
      minimum_coverage 90
      maximum_coverage_drop 5
      
      add_group "Models", "app/models"
      add_group "Controllers", "app/controllers"
      add_group "Services", "app/services"
      add_group "API", "app/controllers/api"
      add_group "Libraries", "lib"
    end
  end
end

# Custom matchers
RSpec::Matchers.define :be_a_valid_uuid do
  match do |actual|
    actual.is_a?(String) && actual.match?(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
  end
  
  failure_message do |actual|
    "expected #{actual.inspect} to be a valid UUID"
  end
end

RSpec::Matchers.define :be_an_admin do
  match do |actual|
    actual.respond_to?(:admin?) && actual.admin?
  end
  
  failure_message do |actual|
    "expected #{actual.inspect} to be an admin"
  end
end

RSpec::Matchers.define :be_a_super_admin do
  match do |actual|
    actual.respond_to?(:super_admin?) && actual.super_admin?
  end
  
  failure_message do |actual|
    "expected #{actual.inspect} to be a super admin"
  end
end

# Test helpers
module TestHelpers
  def sign_in_user(user = nil)
    user ||= create(:user, :confirmed)
    sign_in user
    user
  end

  def sign_in_admin(user = nil)
    user ||= create(:user, :admin, :confirmed)
    sign_in user
    user
  end

  def sign_in_super_admin(user = nil)
    user ||= create(:user, :super_admin, :confirmed)
    sign_in user
    user
  end

  def set_tenant(tenant = nil)
    tenant ||= create(:tenant)
    Tenant.current = tenant
    tenant
  end

  def json_response
    JSON.parse(response.body)
  end

  def expect_json_error(code = 422, message = nil)
    expect(response).to have_http_status(code)
    expect(json_response).to be_a(Hash)
    expect(json_response["error"]).to be_present if message.nil?
    expect(json_response["error"]).to include(message) if message
  end

  def expect_json_success(message = nil)
    expect(response).to have_http_status(:success)
    expect(json_response).to be_a(Hash)
    expect(json_response["success"]).to be true if json_response.key?("success")
    expect(json_response["message"]).to include(message) if message
  end
end

RSpec.configure do |config|
  config.include TestHelpers, type: :controller
  config.include TestHelpers, type: :request
  config.include TestHelpers, type: :feature
  config.include TestHelpers, type: :api
end

# Mock helpers
module MockHelpers
  def mock_keycloak_user(user_attrs = {})
    default_attrs = {
      id: SecureRandom.uuid,
      username: "test_user",
      email: "test@example.com",
      firstName: "Test",
      lastName: "User",
      enabled: true,
      emailVerified: true
    }
    double("Keycloak::User", default_attrs.merge(user_attrs))
  end

  def mock_freeipa_user(user_attrs = {})
    default_attrs = {
      uid: [SecureRandom.uuid],
      givenname: ["Test"],
      sn: ["User"],
      mail: ["test@example.com"],
      loginshell: ["/bin/bash"],
      homedirectory: ["/home/test"]
    }
    double("FreeIPA::User", default_attrs.merge(user_attrs))
  end
end

RSpec.configure do |config|
  config.include MockHelpers, type: :service
end
