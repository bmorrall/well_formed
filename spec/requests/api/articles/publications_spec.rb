# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Articles::Publications", type: :request do
  let(:article) { Article.create!(title: "Draft", body: "Content") }

  describe "POST /api/articles/:article_id/publication" do
    context "with valid params" do
      it "returns 200" do
        post api_article_publication_path(article), params: {publication: {reason: "Ready to ship"}}
        expect(response).to have_http_status(:ok)
      end

      it "publishes the article" do
        post api_article_publication_path(article), params: {publication: {reason: "Ready to ship"}}
        expect(article.reload.published).to be(true)
      end

      it "returns published: true" do
        post api_article_publication_path(article), params: {publication: {reason: "Ready to ship"}}
        expect(response.parsed_body["published"]).to be(true)
      end
    end

    context "with invalid params" do
      it "returns 422" do
        post api_article_publication_path(article), params: {publication: {reason: ""}}
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns validation errors" do
        post api_article_publication_path(article), params: {publication: {reason: ""}}
        expect(response.parsed_body["errors"]["reason"]).to be_present
      end

      it "does not publish the article" do
        post api_article_publication_path(article), params: {publication: {reason: ""}}
        expect(article.reload.published).to be(false)
      end
    end
  end

  describe "PATCH /api/articles/:article_id/publication" do
    let(:article) { Article.create!(title: "Published", body: "Content", published: true) }

    context "with valid params" do
      it "returns 200" do
        patch api_article_publication_path(article), params: {publication: {reason: "No longer accurate"}}
        expect(response).to have_http_status(:ok)
      end

      it "retracts the article" do
        patch api_article_publication_path(article), params: {publication: {reason: "No longer accurate"}}
        expect(article.reload.published).to be(false)
      end

      it "returns published: false" do
        patch api_article_publication_path(article), params: {publication: {reason: "No longer accurate"}}
        expect(response.parsed_body["published"]).to be(false)
      end
    end

    context "with invalid params" do
      it "returns 422" do
        patch api_article_publication_path(article), params: {publication: {reason: ""}}
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns validation errors" do
        patch api_article_publication_path(article), params: {publication: {reason: ""}}
        expect(response.parsed_body["errors"]["reason"]).to be_present
      end

      it "does not retract the article" do
        patch api_article_publication_path(article), params: {publication: {reason: ""}}
        expect(article.reload.published).to be(true)
      end
    end
  end
end
