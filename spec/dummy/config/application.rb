# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"

require "well_formed"
require "simple_form"
require "halitosis"

module Dummy
  class Application < Rails::Application
    config.eager_load = false
    config.logger = Logger.new(IO::NULL)
    config.log_level = :fatal
    config.secret_key_base = "dummy_secret_key_base_for_testing_only"
  end
end
