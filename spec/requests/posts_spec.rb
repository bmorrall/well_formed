# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Posts", type: :request do
  let(:user) { User.first || User.create!(name: "Test User", email: "test@example.com") }

  describe "GET /posts/new" do
    it "returns 200" do
      get "/posts/new"
      expect(response).to have_http_status(:ok)
    end

    it "renders a form posting to /posts" do
      get "/posts/new"
      expect(response.body).to have_selector('form[action="/posts"]')
    end

    it "uses POST method (new record)" do
      get "/posts/new"
      expect(response.body).not_to have_selector('input[name="_method"]', visible: :all)
    end

    it "renders the title and body fields" do
      get "/posts/new"
      expect(response.body).to have_field("post[title]")
      expect(response.body).to have_field("post[body]")
    end
  end

  describe "POST /posts" do
    context "with valid params" do
      it "creates the post and returns 201" do
        expect {
          post "/posts", params: {post: {title: "Hello", body: "World"}}
        }.to change(Post, :count).by(1)
        expect(response).to have_http_status(:created)
        created = Post.last!
        expect(created.title).to eq("Hello")
        expect(created.body).to eq("World")
      end
    end

    context "with invalid params" do
      it "returns 422" do
        post "/posts", params: {post: {title: "", body: ""}}
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "re-renders the form" do
        post "/posts", params: {post: {title: "", body: ""}}
        expect(response.body).to have_selector('form[action="/posts"]')
      end
    end
  end

  describe "GET /posts/:id/edit" do
    let!(:post) { Post.create!(title: "Existing", body: "Body") }

    it "returns 200" do
      get "/posts/#{post.id}/edit"
      expect(response).to have_http_status(:ok)
    end

    it "renders a form posting to /posts/:id" do
      get "/posts/#{post.id}/edit"
      expect(response.body).to have_selector("form[action='/posts/#{post.id}']")
    end

    it "uses PATCH method (persisted record)" do
      get "/posts/#{post.id}/edit"
      expect(response.body).to have_selector('input[name="_method"][value="patch"]', visible: :all)
    end

    it "pre-populates fields with the existing values" do
      get "/posts/#{post.id}/edit"
      expect(response.body).to have_field("post[title]", with: "Existing")
      expect(response.body).to have_field("post[body]", with: "Body")
    end
  end

  describe "PATCH /posts/:id" do
    let!(:post) { Post.create!(title: "Old title", body: "Old body") }

    context "with valid params" do
      it "updates the post and returns 200" do
        patch "/posts/#{post.id}", params: {post: {title: "New title", body: "New body"}}
        expect(response).to have_http_status(:ok)
        post.reload
        expect(post.title).to eq("New title")
        expect(post.body).to eq("New body")
      end
    end

    context "with invalid params" do
      it "returns 422" do
        patch "/posts/#{post.id}", params: {post: {title: "", body: ""}}
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "re-renders the form with the post URL" do
        patch "/posts/#{post.id}", params: {post: {title: "", body: ""}}
        expect(response.body).to have_selector("form[action='/posts/#{post.id}']")
        expect(response.body).to have_selector('input[name="_method"][value="patch"]', visible: :all)
      end
    end
  end
end
