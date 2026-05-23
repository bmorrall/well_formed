# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Users (model-level validation)", type: :request do
  describe "POST /api/users" do
    context "with a valid name and email" do
      it "creates the user and returns 201" do
        post "/api/users", params: {user: {name: "Alice", email: "alice@example.com"}}

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["name"]).to eq("Alice")
        expect(json["email"]).to eq("alice@example.com")
      end
    end

    context "with a name and email that is present but invalid at the model level" do
      # The form only validates presence — it does not check email format.
      # The User model validates format: /\A[^@\s]+@[^@\s]+\z/
      # So the form passes its own validation, but resource.save fails,
      # and the form merges model errors so Halitosis can serialise them.
      before { post "/api/users", params: {user: {name: "Alice", email: "not-an-email"}} }

      it "returns 422" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns a Halitosis error for email from the model validation" do
        error = response.parsed_body["errors"].find { |e| e.dig("source", "pointer") == "/user/email" }
        expect(error).to eq(
          "code" => "email_invalid",
          "detail" => "Email is invalid",
          "source" => {"pointer" => "/user/email"}
        )
      end
    end

    context "with a missing name (form-level validation)" do
      before { post "/api/users", params: {user: {name: "", email: "alice@example.com"}} }

      it "returns 422" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns a Halitosis error for name" do
        error = response.parsed_body["errors"].find { |e| e.dig("source", "pointer") == "/user/name" }
        expect(error).to eq(
          "code" => "name_blank",
          "detail" => "Name can't be blank",
          "source" => {"pointer" => "/user/name"}
        )
      end
    end
  end
end
