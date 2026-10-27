# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Subscriptions", type: :request do
  describe "POST /api/subscription", :aggregate_failures do
    it "subscribes with an email and name" do
      post api_subscription_path, params: {subscription: {email: "alice@example.com", name: "Alice"}}

      expect(response).to have_http_status(:created)

      json = response.parsed_body
      expect(json["email"]).to eq("alice@example.com")
      expect(json["name"]).to eq("Alice")
      expect(json["subscribed"]).to be(true)
    end

    it "rejects a blank email and name" do
      post api_subscription_path, params: {subscription: {email: "", name: ""}}

      expect(response).to have_http_status(:unprocessable_content)

      json = response.parsed_body
      expect(json["errors"]["email"]).to include("can't be blank")
      expect(json["errors"]["name"]).to include("can't be blank")
    end
  end
end
