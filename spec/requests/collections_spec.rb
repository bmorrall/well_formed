# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Collections", type: :request do
  describe "GET /posts/new", :aggregate_failures do
    it "renders a select for user_id built from collection_for_user_id" do
      User.create!(name: "Alice", email: "alice@example.com")
      User.create!(name: "Bob", email: "bob@example.com")

      get new_post_path

      expect(response).to have_http_status(:ok)

      expect(response.body).to have_select("post[user_id]", with_options: ["Alice"])
      expect(response.body).to have_select("post[user_id]", with_options: ["Bob"])
    end
  end

  describe "POST /posts", :aggregate_failures do
    it "creates a post with a user_id from the collection" do
      user = User.create!(name: "Alice", email: "alice@example.com")

      expect {
        post posts_path, params: {post: {title: "Hello", body: "World", user_id: user.id}}
      }.to change(Post, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it "creates a post with a nil user_id, as blank values skip validation" do
      expect {
        post posts_path, params: {post: {title: "Hello", body: "World", user_id: nil}}
      }.to change(Post, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it "shows an inclusion error for a user_id not in the collection" do
      expect {
        post posts_path, params: {post: {title: "Hello", body: "World", user_id: 9999}}
      }.not_to change(Post, :count)

      expect(response).to have_http_status(:unprocessable_content)

      expect(response.body).to have_css("span.post_user_id-error", text: "is not included in the list")
    end
  end
end
