# frozen_string_literal: true

require "temping"

RSpec.configure do |config|
  config.after do
    Temping.teardown
  end
end
