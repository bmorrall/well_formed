# frozen_string_literal: true

class PostsController < ApplicationController
  layout false

  # GET /posts/new
  def new
    @form = CreatePostForm.new(Post.new, current_user)
  end

  # GET /posts/:id/edit
  def edit
    @form = UpdatePostForm.new(Post.find(params.require(:id)), current_user)
  end

  # POST /posts
  def create
    @form = CreatePostForm.new(Post.new, current_user, post_params)
    if @form.save
      head :created
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH /posts/:id
  def update
    @form = UpdatePostForm.new(Post.find(params.require(:id)), current_user, post_params)
    if @form.save
      head :ok
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def post_params
    params.require(:post).permit(:title, :body, :user_id)
  end
end
