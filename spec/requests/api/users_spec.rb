# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Users (model-level validation)", type: :request do
  describe "POST /api/users", :aggregate_failures do
    it "creates a user with a valid name and email" do
      email = "alice@example.com"

      expect {
        post api_users_path, params: {user: {name: "Alice", email:}}
      }.to change { User.exists?(email:) }.from(false).to(true)

      expect(response).to have_http_status(:created)

      json = response.parsed_body
      expect(json["name"]).to eq("Alice")
      expect(json["email"]).to eq(email)
    end

    # The form only validates presence; it does not check email format.
    # The User model validates format, so the form passes its own validation,
    # resource.save fails, and the form merges the model errors so Halitosis
    # can serialise them.
    it "rejects an email that is invalid at the model level" do
      email = "not-an-email"

      expect {
        post api_users_path, params: {user: {name: "Alice", email:}}
      }.not_to change { User.exists?(email:) }

      expect(response).to have_http_status(:unprocessable_content)

      error = response.parsed_body["errors"].find { |e| e.dig("source", "pointer") == "/user/email" }
      expect(error).to eq(
        "code" => "email_invalid",
        "detail" => "Email is invalid",
        "source" => {"pointer" => "/user/email"}
      )
    end

    it "rejects a missing name at the form level" do
      email = "alice@example.com"

      expect {
        post api_users_path, params: {user: {name: "", email:}}
      }.not_to change { User.exists?(email:) }

      expect(response).to have_http_status(:unprocessable_content)

      error = response.parsed_body["errors"].find { |e| e.dig("source", "pointer") == "/user/name" }
      expect(error).to eq(
        "code" => "name_blank",
        "detail" => "Name can't be blank",
        "source" => {"pointer" => "/user/name"}
      )
    end
  end
end
