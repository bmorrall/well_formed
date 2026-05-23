# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::UserProfiles", type: :request do
  let!(:user) { User.create!(name: "Original Name", email: "original@example.com") }

  describe "PATCH /user_profile" do
    context "with valid params" do
      it "returns 200 with the updated profile" do
        patch "/api/user_profile", params: {user_profile: {name: "New Name", email: "new@example.com"}}

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["name"]).to eq("New Name")
        expect(json["email"]).to eq("new@example.com")
      end

      it "persists the update" do
        patch "/api/user_profile", params: {user_profile: {name: "New Name", email: "new@example.com"}}

        expect(user.reload.name).to eq("New Name")
      end
    end

    context "with invalid params" do
      it "returns 422 with validation errors" do
        patch "/api/user_profile", params: {user_profile: {name: "", email: ""}}

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json["errors"]["name"]).to include("can't be blank")
        expect(json["errors"]["email"]).to include("can't be blank")
      end

      it "does not update the profile" do
        patch "/api/user_profile", params: {user_profile: {name: ""}}

        expect(user.reload.name).to eq("Original Name")
      end
    end
  end
end
