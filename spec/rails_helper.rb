# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "dummy/config/environment"
require "rspec/rails"
require "capybara/rspec"

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!

  config.include Capybara::RSpecMatchers

  config.before(:suite) do
    ActiveRecord::Schema.verbose = false
    load Rails.root.join("db/schema.rb").to_s
  end
end
