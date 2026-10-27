# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SimpleForm::Posts", type: :request do
  describe "GET /simple_form/posts/new", :aggregate_failures do
    it "renders a select for user_id populated from collection_for_user_id" do
      User.create!(name: "Alice", email: "alice@example.com")
      User.create!(name: "Bob", email: "bob@example.com")

      get new_simple_form_post_path

      expect(response).to have_http_status(:ok)

      expect(response.body).to have_select("post[user_id]", with_options: ["Alice"])
      expect(response.body).to have_select("post[user_id]", with_options: ["Bob"])
    end
  end

  describe "POST /simple_form/posts", :aggregate_failures do
    it "creates a post with a user_id from the collection" do
      user = User.create!(name: "Alice", email: "alice@example.com")

      expect {
        post simple_form_posts_path, params: {post: {title: "Hello", body: "World", user_id: user.id}}
      }.to change(Post, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it "shows an inline error for a user_id not in the collection" do
      expect {
        post simple_form_posts_path, params: {post: {title: "Hello", body: "World", user_id: 9999}}
      }.not_to change(Post, :count)

      expect(response).to have_http_status(:unprocessable_content)

      expect(response.body).to have_css(".post_user_id span.error", text: "is not included in the list")
    end
  end
end
