# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Articles", type: :request do
  let!(:user) { User.create!(name: "Test User", email: "test@example.com") }

  describe "POST /articles" do
    context "with valid params" do
      it "returns 201 with the created article" do
        post "/api/articles", params: {article: {title: "Hello World", body: "My first article"}}

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["title"]).to eq("Hello World")
        expect(json["body"]).to eq("My first article")
        expect(json["published"]).to be(false)
      end

      it "persists the article" do
        expect {
          post "/api/articles", params: {article: {title: "Hello World", body: "My first article"}}
        }.to change(Article, :count).by(1)
      end

      it "can create a published article" do
        post "/api/articles", params: {article: {title: "Published", body: "Content", published: true}}

        expect(response).to have_http_status(:created)
        expect(Article.last.published).to be(true)
      end
    end

    context "with invalid params" do
      it "returns 422 with validation errors" do
        post "/api/articles", params: {article: {title: "", body: ""}}

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json["errors"]["title"]).to include("can't be blank")
        expect(json["errors"]["body"]).to include("can't be blank")
      end

      it "does not create an article" do
        expect {
          post "/api/articles", params: {article: {title: "", body: ""}}
        }.not_to change(Article, :count)
      end
    end
  end

  describe "PATCH /articles/:id" do
    let!(:article) { Article.create!(title: "Original Title", body: "Original Body") }

    context "with valid params" do
      it "returns 200 with the updated article" do
        patch "/api/articles/#{article.id}", params: {article: {title: "Updated Title", body: "Updated Body"}}

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["id"]).to eq(article.id)
        expect(json["title"]).to eq("Updated Title")
        expect(json["body"]).to eq("Updated Body")
      end

      it "persists the update" do
        patch "/api/articles/#{article.id}", params: {article: {title: "Updated Title", body: "Updated Body"}}

        article.reload
        expect(article.title).to eq("Updated Title")
        expect(article.body).to eq("Updated Body")
      end

      it "can publish an article" do
        patch "/api/articles/#{article.id}", params: {article: {title: "Updated", body: "Updated", published: true}}

        expect(article.reload.published).to be(true)
      end
    end

    context "with invalid params" do
      it "returns 422 with validation errors" do
        patch "/api/articles/#{article.id}", params: {article: {title: ""}}

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]["title"]).to include("can't be blank")
      end

      it "does not update the article" do
        patch "/api/articles/#{article.id}", params: {article: {title: ""}}

        expect(article.reload.title).to eq("Original Title")
      end
    end
  end
end
