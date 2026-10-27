# frozen_string_literal: true

module FormSpecHelpers
  extend RSpec::Matchers::DSL

  matcher :have_patch_method_input do
    match { |actual| expect(actual).to have_css("input[name='_method'][value='patch']", visible: :all) }
  end
end

RSpec.configure do |config|
  config.include FormSpecHelpers, type: :request
end
