# SimpleCov configuration for Aurid
# This file configures test coverage reporting

require "simplecov"
require "simplecov-console"

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::Console,
  SimpleCov::Formatter::JSONFormatter
])

SimpleCov.configure do
  # Coverage criteria
  minimum_coverage 90
  maximum_coverage_drop 5
  
  # Minimum coverage by file
  minimum_coverage_by_file 80
  
  # Refuse to let coverage drop below this percentage
  refuse_to_let_coverage_drop_below 85
  
  # Files to include in coverage
  add_filter do |src_file|
    # Skip files we don't want to track
    src_file.path =~ /\/spec\// ||
    src_file.path =~ /\/test\// ||
    src_file.path =~ /\/config\// ||
    src_file.path =~ /\/db\/migrate\// ||
    src_file.path =~ /\/lib\/tasks\// ||
    src_file.path =~ /\/vendor\// ||
    src_file.path =~ /\.git\//
  end
  
  # Groups for coverage reporting
  add_group "Models", "app/models"
  add_group "Controllers", "app/controllers"
  add_group "Services", "app/services"
  add_group "API Controllers", "app/controllers/api"
  add_group "Libraries", "lib"
  add_group "Background Jobs", "app/jobs"
  add_group "Helpers", "app/helpers"
  add_group "Mailers", "app/mailers"
  add_group "Policies", "app/policies"
  add_group "Presenters", "app/presenters"
  
  # Track files even if they're not required
  track_files "app/**/*.rb"
  
  # Don't track files that don't exist
  track_files "lib/**/*.rb"
  
  # Profile for CI
  profile "ci" do
    formatter SimpleCov::Formatter::JSONFormatter
    command_name "CI"
  end
  
  # Profile for local development
  profile "local" do
    formatter SimpleCov::Formatter::HTMLFormatter
    command_name "Local"
  end
  
  # Profile for console output
  profile "console" do
    formatter SimpleCov::Formatter::Console
    command_name "Console"
  end
end

# Load the profile based on environment
if ENV["CI"]
  SimpleCov.command_name "CI-#{ENV.fetch('GITHUB_ACTION', 'Unknown')}"
  SimpleCov.profile "ci"
elsif ENV["COVERAGE"] == "true"
  SimpleCov.profile "local"
else
  SimpleCov.profile "console"
end

# Start SimpleCov
SimpleCov.start do
  # Additional configuration can go here
  
  # Enable coverage for Rails
  add_filter "/gems/"
  add_filter "/.bundle/"
  
  # Track all Ruby files in app and lib
  track_files "{app,lib}/**/*.rb"
end
