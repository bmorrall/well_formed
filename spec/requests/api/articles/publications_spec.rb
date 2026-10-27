# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Articles::Publications", type: :request do
  describe "POST /api/articles/:article_id/publication", :aggregate_failures do
    it "publishes the article with a reason" do
      article = Article.create!(title: "Draft", body: "Content")

      expect {
        post api_article_publication_path(article), params: {publication: {reason: "Ready to ship"}}
      }.to change { article.reload.published }.from(false).to(true)

      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json["published"]).to be(true)
    end

    it "rejects a blank reason" do
      article = Article.create!(title: "Draft", body: "Content")

      expect {
        post api_article_publication_path(article), params: {publication: {reason: ""}}
      }.not_to change { article.reload.published }

      expect(response).to have_http_status(:unprocessable_content)

      json = response.parsed_body
      expect(json["errors"]["reason"]).to be_present
    end
  end

  describe "PATCH /api/articles/:article_id/publication", :aggregate_failures do
    it "retracts the article with a reason" do
      article = Article.create!(title: "Published", body: "Content", published: true)

      expect {
        patch api_article_publication_path(article), params: {publication: {reason: "No longer accurate"}}
      }.to change { article.reload.published }.from(true).to(false)

      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json["published"]).to be(false)
    end

    it "rejects a blank reason" do
      article = Article.create!(title: "Published", body: "Content", published: true)

      expect {
        patch api_article_publication_path(article), params: {publication: {reason: ""}}
      }.not_to change { article.reload.published }

      expect(response).to have_http_status(:unprocessable_content)

      json = response.parsed_body
      expect(json["errors"]["reason"]).to be_present
    end
  end
end
