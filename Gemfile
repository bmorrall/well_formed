# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in well_formed.gemspec
gemspec

gem "irb"
gem "rake", "~> 13.0"

gem "rspec", "~> 3.0"
gem "simplecov", require: false

rails_version = ENV["RAILS_VERSION"]
gem "rails", rails_version ? "~> #{rails_version}.0" : ">= 7.2"
gem "sqlite3"
gem "rspec-rails"
gem "capybara"
gem "generator_spec"

gem "simple_form"

gem "halitosis", github: "bmorrall/halitosis"

gem "standard", "~> 1.3"
gem "rubocop-rails", require: false
gem "rbs"

gem "steep", "~> 2.0", group: :development
