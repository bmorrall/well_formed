# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Posts::Publications", type: :request do
  let(:the_post) { Post.create!(title: "Hello", body: "World") }

  describe "POST /posts/:post_id/publication" do
    context "with valid params" do
      it "returns 200" do
        post post_publication_path(the_post), params: {publication: {reason: "Ready to ship"}}
        expect(response).to have_http_status(:ok)
      end

      it "publishes the post" do
        post post_publication_path(the_post), params: {publication: {reason: "Ready to ship"}}
        expect(the_post.reload.published).to be(true)
      end
    end

    context "with invalid params" do
      it "returns 422" do
        post post_publication_path(the_post), params: {publication: {reason: ""}}
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "does not publish the post" do
        post post_publication_path(the_post), params: {publication: {reason: ""}}
        expect(the_post.reload.published).to be(false)
      end
    end
  end

  describe "PATCH /posts/:post_id/publication" do
    let(:the_post) { Post.create!(title: "Hello", body: "World", published: true) }

    context "with valid params" do
      it "returns 200" do
        patch post_publication_path(the_post), params: {publication: {reason: "No longer relevant"}}
        expect(response).to have_http_status(:ok)
      end

      it "retracts the post" do
        patch post_publication_path(the_post), params: {publication: {reason: "No longer relevant"}}
        expect(the_post.reload.published).to be(false)
      end
    end

    context "with invalid params" do
      it "returns 422" do
        patch post_publication_path(the_post), params: {publication: {reason: ""}}
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "does not retract the post" do
        patch post_publication_path(the_post), params: {publication: {reason: ""}}
        expect(the_post.reload.published).to be(true)
      end
    end
  end
end
