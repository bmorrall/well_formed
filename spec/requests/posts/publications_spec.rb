# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Posts::Publications", type: :request do
  describe "POST /posts/:post_id/publication", :aggregate_failures do
    it "publishes the post" do
      draft = Post.create!(title: "Hello", body: "World")

      expect {
        post post_publication_path(draft), params: {publication: {reason: "Ready to ship"}}
      }.to change { draft.reload.published }.from(false).to(true)

      expect(response).to have_http_status(:ok)
    end

    it "does not publish the post without a reason" do
      draft = Post.create!(title: "Hello", body: "World")

      expect {
        post post_publication_path(draft), params: {publication: {reason: ""}}
      }.not_to change { draft.reload.published }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /posts/:post_id/publication", :aggregate_failures do
    it "retracts the post" do
      published_post = Post.create!(title: "Hello", body: "World", published: true)

      expect {
        patch post_publication_path(published_post), params: {publication: {reason: "No longer relevant"}}
      }.to change { published_post.reload.published }.from(true).to(false)

      expect(response).to have_http_status(:ok)
    end

    it "does not retract the post without a reason" do
      published_post = Post.create!(title: "Hello", body: "World", published: true)

      expect {
        patch post_publication_path(published_post), params: {publication: {reason: ""}}
      }.not_to change { published_post.reload.published }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
