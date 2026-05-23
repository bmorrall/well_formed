# frozen_string_literal: true

module SimpleForm
  class PostsController < ApplicationController
    layout false

    # GET /simple_form/posts/new
    def new
      @form = CreatePostForm.new(Post.new, current_user)
    end

    # GET /simple_form/posts/:id/edit
    def edit
      @form = UpdatePostForm.new(Post.find(params.expect(:id)), current_user)
    end

    # POST /simple_form/posts
    def create
      @form = CreatePostForm.new(Post.new, current_user, post_params)
      if @form.save
        head :created
      else
        render :new, status: :unprocessable_content
      end
    end

    # PATCH /simple_form/posts/:id
    def update
      @form = UpdatePostForm.new(Post.find(params.expect(:id)), current_user, post_params)
      if @form.save
        head :ok
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def post_params
      params.expect(post: [:title, :body, :user_id])
    end
  end
end
