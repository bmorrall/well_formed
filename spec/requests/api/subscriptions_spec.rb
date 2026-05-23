# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Subscriptions", type: :request do
  describe "POST /api/subscription" do
    context "with valid params" do
      it "returns 201" do
        post "/api/subscription", params: {subscription: {email: "alice@example.com", name: "Alice"}}

        expect(response).to have_http_status(:created)
      end

      it "returns the subscription details" do
        post "/api/subscription", params: {subscription: {email: "alice@example.com", name: "Alice"}}

        json = response.parsed_body
        expect(json["email"]).to eq("alice@example.com")
        expect(json["name"]).to eq("Alice")
        expect(json["subscribed"]).to be(true)
      end
    end

    context "with invalid params" do
      it "returns 422" do
        post "/api/subscription", params: {subscription: {email: "", name: ""}}

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns validation errors" do
        post "/api/subscription", params: {subscription: {email: "", name: ""}}

        json = response.parsed_body
        expect(json["errors"]["email"]).to include("can't be blank")
        expect(json["errors"]["name"]).to include("can't be blank")
      end
    end
  end
end
