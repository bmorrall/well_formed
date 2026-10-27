# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Posts (resolves_to:)", type: :request do
  describe "POST /api/posts (code → id)", :aggregate_failures do
    it "creates the post with the user_id resolved from a valid user code" do
      user = User.create!(name: "Alice", email: "alice@example.com", code: "ALICE")

      expect {
        post api_posts_path, params: {post: {title: "Hello", user_id: "ALICE"}}
      }.to change(Post, :count).by(1)

      expect(response).to have_http_status(:created)

      post_record = Post.last
      expect(post_record.user_id).to eq(user.id)
    end

    it "rejects an unknown user code" do
      expect {
        post api_posts_path, params: {post: {title: "Hello", user_id: "MISSING"}}
      }.not_to change(Post, :count)

      expect(response).to have_http_status(:unprocessable_content)

      error = response.parsed_body["errors"].find { |e| e.dig("source", "pointer") == "/post/user_id" }
      expect(error).to eq(
        "code" => "user_id_inclusion",
        "detail" => "User is not included in the list",
        "source" => {"pointer" => "/post/user_id"}
      )
    end
  end

  describe "PATCH /api/posts/:id (id → code)", :aggregate_failures do
    it "updates the post with the user_code resolved from a valid user id" do
      post_record = Post.create!(title: "Old", body: "")
      user = User.create!(name: "Alice", email: "alice@example.com", code: "ALICE")

      expect {
        patch api_post_path(post_record), params: {post: {title: "Updated", user_code: user.id}}
      }.to change { post_record.reload.user_code }.to("ALICE")

      expect(response).to have_http_status(:ok)
    end

    it "rejects an unknown user id" do
      post_record = Post.create!(title: "Old", body: "")

      expect {
        patch api_post_path(post_record), params: {post: {title: "Updated", user_code: 9999}}
      }.not_to change { post_record.reload.attributes.slice("title", "user_code") }

      expect(response).to have_http_status(:unprocessable_content)

      error = response.parsed_body["errors"].find { |e| e.dig("source", "pointer") == "/post/user_code" }
      expect(error).to eq(
        "code" => "user_code_inclusion",
        "detail" => "User code is not included in the list",
        "source" => {"pointer" => "/post/user_code"}
      )
    end
  end
end
