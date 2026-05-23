# frozen_string_literal: true

module Api
  class PostsController < BaseController
    # POST /api/posts
    def create
      post = Post.new
      @form = Api::CreatePostForm.new(post, current_user, post_create_params)
      if @form.save
        render json: {id: post.id, title: post.title, user_id: post.user_id}, status: :created
      else
        render json: Halitosis::ErrorsSerializer.new(@form), status: :unprocessable_content
      end
    end

    # PATCH /api/posts/:id
    def update
      post = Post.find(params.expect(:id))
      @form = Api::UpdatePostForm.new(post, current_user, post_update_params)
      if @form.save
        render json: {id: post.id, title: post.title, user_code: post.user_code}, status: :ok
      else
        render json: Halitosis::ErrorsSerializer.new(@form), status: :unprocessable_content
      end
    end

    private

    def post_create_params
      params.expect(post: [:title, :user_id])
    end

    def post_update_params
      params.expect(post: [:title, :user_code])
    end
  end
end
