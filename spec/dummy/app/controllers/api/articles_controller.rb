# frozen_string_literal: true

module Api
  class ArticlesController < BaseController
    # POST /api/articles
    def create
      form = CreateArticleForm.new(Article.new, current_user, article_params)

      if (article = form.submit)
        render json: article.as_json, status: :created
      else
        render json: {errors: form.errors.messages}, status: :unprocessable_content
      end
    end

    # PATCH /api/articles/:id
    def update
      form = UpdateArticleForm.new(Article.find(params.require(:id)), current_user, article_params)

      if (article = form.submit)
        render json: article.as_json, status: :ok
      else
        render json: {errors: form.errors.messages}, status: :unprocessable_content
      end
    end

    private

    def article_params
      params.require(:article).permit(:title, :body, :published)
    end
  end
end
