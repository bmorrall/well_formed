# frozen_string_literal: true

module Api
  module Articles
    class PublicationsController < BaseController
      before_action :set_article

      # POST /api/articles/:article_id/publication
      def create
        action = PublishArticleForm.new(@article, current_user, publication_params)

        if action.submit
          render json: {published: true}, status: :ok
        else
          render json: {errors: action.errors.messages}, status: :unprocessable_content
        end
      end

      # PATCH /api/articles/:article_id/publication
      def update
        action = RetractArticleForm.new(@article, current_user, publication_params)

        if action.submit
          render json: {published: false}, status: :ok
        else
          render json: {errors: action.errors.messages}, status: :unprocessable_content
        end
      end

      private

      def set_article
        @article = Article.find(params.require(:article_id))
      end

      def publication_params
        params.require(:publication).permit(:reason)
      end
    end
  end
end
