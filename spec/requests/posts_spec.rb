# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Posts", type: :request do
  describe "GET /posts/new", :aggregate_failures do
    it "renders a form for a new post" do
      get new_post_path

      expect(response).to have_http_status(:ok)

      expect(response.body).to have_css("form[action='#{posts_path}']")
      expect(response.body).not_to have_patch_method_input
      expect(response.body).to have_field("post[title]")
      expect(response.body).to have_field("post[body]")
    end
  end

  describe "POST /posts", :aggregate_failures do
    it "creates a post" do
      expect {
        post posts_path, params: {post: {title: "Hello", body: "World"}}
      }.to change(Post, :count).by(1)

      expect(response).to have_http_status(:created)

      created_post = Post.last!
      expect(created_post).to have_attributes(title: "Hello", body: "World")
    end

    it "re-renders the form when the post is invalid" do
      expect {
        post posts_path, params: {post: {title: "", body: ""}}
      }.not_to change(Post, :count)

      expect(response).to have_http_status(:unprocessable_content)

      expect(response.body).to have_css("form[action='#{posts_path}']")
    end
  end

  describe "GET /posts/:id/edit", :aggregate_failures do
    it "renders a form for the existing post" do
      existing_post = Post.create!(title: "Existing", body: "Body")

      get edit_post_path(existing_post)

      expect(response).to have_http_status(:ok)

      expect(response.body).to have_css("form[action='#{post_path(existing_post)}']")
      expect(response.body).to have_patch_method_input
      expect(response.body).to have_field("post[title]", with: "Existing")
      expect(response.body).to have_field("post[body]", with: "Body")
    end
  end

  describe "PATCH /posts/:id", :aggregate_failures do
    it "updates the post" do
      existing_post = Post.create!(title: "Old title", body: "Old body")

      expect {
        patch post_path(existing_post), params: {post: {title: "New title", body: "New body"}}
      }.to change { existing_post.reload.title }.to("New title")
        .and change { existing_post.reload.body }.to("New body")

      expect(response).to have_http_status(:ok)
    end

    it "re-renders the form when the post is invalid" do
      existing_post = Post.create!(title: "Old title", body: "Old body")

      expect {
        patch post_path(existing_post), params: {post: {title: "", body: ""}}
      }.not_to change { existing_post.reload.attributes }

      expect(response).to have_http_status(:unprocessable_content)

      expect(response.body).to have_css("form[action='#{post_path(existing_post)}']")
      expect(response.body).to have_patch_method_input
    end
  end
end
