# frozen_string_literal: true

module WellFormed
  class Railtie < Rails::Railtie
    generators do
      require_relative "../../generators/resource_form_generator"
    end
  end
end
