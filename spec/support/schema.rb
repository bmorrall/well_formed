# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:suite) do
    ActiveRecord::Schema.verbose = false
    load Rails.root.join("db/schema.rb").to_s
  end
end
