# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Subscriptions", type: :request do
  describe "GET /subscription/new", :aggregate_failures do
    it "renders a form for a new subscription" do
      get new_subscription_path

      expect(response).to have_http_status(:ok)

      expect(response.body).to have_css("form[action='#{subscription_path}']")
      expect(response.body).to have_field("subscription[name]")
      expect(response.body).to have_field("subscription[email]")
    end
  end

  describe "POST /subscription", :aggregate_failures do
    it "subscribes" do
      post subscription_path, params: {subscription: {name: "Alice", email: "alice@example.com"}}

      expect(response).to have_http_status(:created)
    end

    it "re-renders the form when the subscription is invalid" do
      post subscription_path, params: {subscription: {name: "", email: ""}}

      expect(response).to have_http_status(:unprocessable_content)

      expect(response.body).to have_css("form[action='#{subscription_path}']")
    end
  end
end
