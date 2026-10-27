# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::UserProfiles", type: :request do
  describe "PATCH /api/user_profile", :aggregate_failures do
    it "updates the current user's profile" do
      user = User.create!(name: "Original Name", email: "original@example.com")

      expect {
        patch api_user_profile_path, params: {user_profile: {name: "New Name", email: "new@example.com"}}
      }.to change { user.reload.name }.to("New Name")
        .and change { user.reload.email }.to("new@example.com")

      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json["name"]).to eq("New Name")
      expect(json["email"]).to eq("new@example.com")
    end

    it "rejects a blank name and email" do
      user = User.create!(name: "Original Name", email: "original@example.com")

      expect {
        patch api_user_profile_path, params: {user_profile: {name: "", email: ""}}
      }.not_to change { user.reload.attributes.slice("name", "email") }

      expect(response).to have_http_status(:unprocessable_content)

      json = response.parsed_body
      expect(json["errors"]["name"]).to include("can't be blank")
      expect(json["errors"]["email"]).to include("can't be blank")
    end
  end
end
