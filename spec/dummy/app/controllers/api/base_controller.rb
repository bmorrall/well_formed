# frozen_string_literal: true

module Api
  class BaseController < ActionController::API
    private

    def current_user
      @current_user ||= User.first || User.create!(name: "Test User", email: "test@example.com")
    end
  end
end
