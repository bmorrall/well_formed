# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new(:rubocop)

EXTENSION_GEMS = Dir.glob(File.join(__dir__, "gems", "*")).select { |d| File.directory?(d) }

namespace :gems do
  task install: :environment do
    EXTENSION_GEMS.each do |gem_dir|
      sh "bundle install", chdir: gem_dir
    end
  end

  task spec: :environment do
    EXTENSION_GEMS.each do |gem_dir|
      sh "bundle exec rake spec", chdir: gem_dir
    end
  end

  task rubocop: :environment do
    EXTENSION_GEMS.each do |gem_dir|
      sh "bundle exec rake rubocop", chdir: gem_dir
    end
  end

  task all: %i[spec rubocop]
end

task default: %i[spec rubocop]
