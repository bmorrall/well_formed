# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Subscriptions", type: :request do
  describe "GET /subscription/new" do
    it "returns 200" do
      get "/subscription/new"
      expect(response).to have_http_status(:ok)
    end

    it "renders a form posting to /subscription" do
      get "/subscription/new"
      expect(response.body).to have_selector('form[action="/subscription"]')
    end

    it "renders the name and email fields" do
      get "/subscription/new"
      expect(response.body).to have_field("subscription[name]")
      expect(response.body).to have_field("subscription[email]")
    end
  end

  describe "POST /subscription" do
    context "with valid params" do
      it "returns 201" do
        post "/subscription", params: {subscription: {name: "Alice", email: "alice@example.com"}}
        expect(response).to have_http_status(:created)
      end
    end

    context "with invalid params" do
      it "returns 422" do
        post "/subscription", params: {subscription: {name: "", email: ""}}
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "re-renders the form" do
        post "/subscription", params: {subscription: {name: "", email: ""}}
        expect(response.body).to have_selector('form[action="/subscription"]')
      end
    end
  end
end
