# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Collections", type: :request do
  describe "collection_for validation (POST /posts)" do
    context "with a valid user_id" do
      it "creates the post and returns 201" do
        user = User.create!(name: "Alice", email: "alice@example.com")
        post "/posts", params: {post: {title: "Hello", body: "World", user_id: user.id}}
        expect(response).to have_http_status(:created)
      end
    end

    context "with a non-existent user_id" do
      it "returns 422 with an inclusion error on user_id" do
        post "/posts", params: {post: {title: "Hello", body: "World", user_id: 9999}}
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to have_css("span.post_user_id-error", text: "is not included in the list")
      end
    end

    context "with a nil user_id" do
      it "creates the post and returns 201 (blank values skip validation)" do
        post "/posts", params: {post: {title: "Hello", body: "World", user_id: nil}}
        expect(response).to have_http_status(:created)
      end
    end
  end

  describe "GET /posts/new" do
    it "renders a select for user_id built from collection_for_user_id" do
      User.create!(name: "Alice", email: "alice@example.com")
      User.create!(name: "Bob", email: "bob@example.com")

      get "/posts/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to have_select("post[user_id]", with_options: ["Alice", "Bob"])
    end
  end
end
