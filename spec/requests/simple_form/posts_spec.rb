# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SimpleForm::Posts", type: :request do
  let!(:alice) { User.create!(name: "Alice", email: "alice@example.com") }
  let!(:bob) { User.create!(name: "Bob", email: "bob@example.com") }

  describe "GET /simple_form/posts/new" do
    it "returns 200" do
      get "/simple_form/posts/new"
      expect(response).to have_http_status(:ok)
    end

    it "renders a select for user_id populated from collection_for_user_id" do
      get "/simple_form/posts/new"
      expect(response.body).to have_select("post[user_id]", with_options: ["Alice", "Bob"])
    end
  end

  describe "POST /simple_form/posts" do
    context "with a valid user_id" do
      it "creates the post and returns 201" do
        post "/simple_form/posts", params: {post: {title: "Hello", body: "World", user_id: alice.id}}
        expect(response).to have_http_status(:created)
      end
    end

    context "with a non-existent user_id" do
      it "returns 422 with an inline error" do
        post "/simple_form/posts", params: {post: {title: "Hello", body: "World", user_id: 9999}}
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to have_css(".post_user_id span.error", text: "is not included in the list")
      end
    end
  end
end
