# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Posts (resolves_to:)", type: :request do
  describe "POST /api/posts (code → id)" do
    context "with a valid user code" do
      it "creates the post, resolves to user_id, and returns 201" do
        user = User.create!(name: "Alice", email: "alice@example.com", code: "ALICE")

        post "/api/posts", params: {post: {title: "Hello", user_id: "ALICE"}}

        expect(response).to have_http_status(:created)
        expect(Post.last.user_id).to eq(user.id)
      end
    end

    context "with an invalid user code" do
      before { post "/api/posts", params: {post: {title: "Hello", user_id: "MISSING"}} }

      it "returns 422" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns a Halitosis error for user_id" do
        error = response.parsed_body["errors"].find { |e| e.dig("source", "pointer") == "/post/user_id" }
        expect(error).to eq(
          "code" => "user_id_inclusion",
          "detail" => "User is not included in the list",
          "source" => {"pointer" => "/post/user_id"}
        )
      end
    end
  end

  describe "PATCH /api/posts/:id (id → code)" do
    let!(:post_record) { Post.create!(title: "Old", body: "") }

    context "with a valid user id" do
      it "updates the post, resolves to user_code, and returns 200" do
        user = User.create!(name: "Alice", email: "alice@example.com", code: "ALICE")

        patch "/api/posts/#{post_record.id}", params: {post: {title: "Updated", user_code: user.id}}

        expect(response).to have_http_status(:ok)
        expect(post_record.reload.user_code).to eq("ALICE")
      end
    end

    context "with an invalid user id" do
      before { patch "/api/posts/#{post_record.id}", params: {post: {title: "Updated", user_code: 9999}} }

      it "returns 422" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns a Halitosis error for user_code" do
        error = response.parsed_body["errors"].find { |e| e.dig("source", "pointer") == "/post/user_code" }
        expect(error).to eq(
          "code" => "user_code_inclusion",
          "detail" => "User code is not included in the list",
          "source" => {"pointer" => "/post/user_code"}
        )
      end
    end
  end
end
