# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Articles", type: :request do
  describe "POST /api/articles", :aggregate_failures do
    it "creates an unpublished article" do
      expect {
        post api_articles_path, params: {article: {title: "Hello World", body: "My first article"}}
      }.to change(Article, :count).by(1)

      expect(response).to have_http_status(:created)

      json = response.parsed_body
      expect(json["title"]).to eq("Hello World")
      expect(json["body"]).to eq("My first article")
      expect(json["published"]).to be(false)
    end

    it "creates a published article" do
      expect {
        post api_articles_path, params: {article: {title: "Published", body: "Content", published: true}}
      }.to change(Article, :count).by(1)

      expect(response).to have_http_status(:created)

      article = Article.last
      expect(article.published).to be(true)
    end

    it "rejects a blank title and body" do
      expect {
        post api_articles_path, params: {article: {title: "", body: ""}}
      }.not_to change(Article, :count)

      expect(response).to have_http_status(:unprocessable_content)

      json = response.parsed_body
      expect(json["errors"]["title"]).to include("can't be blank")
      expect(json["errors"]["body"]).to include("can't be blank")
    end
  end

  describe "PATCH /api/articles/:id", :aggregate_failures do
    it "updates the article" do
      article = Article.create!(title: "Original Title", body: "Original Body")

      expect {
        patch api_article_path(article), params: {article: {title: "Updated Title", body: "Updated Body"}}
      }.to change { article.reload.title }.to("Updated Title")
        .and change { article.reload.body }.to("Updated Body")

      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json["id"]).to eq(article.id)
      expect(json["title"]).to eq("Updated Title")
      expect(json["body"]).to eq("Updated Body")
    end

    it "publishes the article" do
      article = Article.create!(title: "Original Title", body: "Original Body")

      expect {
        patch api_article_path(article), params: {article: {title: "Updated", body: "Updated", published: true}}
      }.to change { article.reload.published }.from(false).to(true)

      expect(response).to have_http_status(:ok)
    end

    it "rejects a blank title" do
      article = Article.create!(title: "Original Title", body: "Original Body")

      expect {
        patch api_article_path(article), params: {article: {title: ""}}
      }.not_to change { article.reload.title }

      expect(response).to have_http_status(:unprocessable_content)

      json = response.parsed_body
      expect(json["errors"]["title"]).to include("can't be blank")
    end
  end
end
