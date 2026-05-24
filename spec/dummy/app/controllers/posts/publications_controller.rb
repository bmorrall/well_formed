# frozen_string_literal: true

class Posts::PublicationsController < ApplicationController
  before_action :set_post

  # POST /posts/:post_id/publication
  def create
    @action = Posts::PublishForm.new(@post, current_user, publication_params)

    if @action.submit
      head :ok
    else
      head :unprocessable_content
    end
  end

  # PATCH /posts/:post_id/publication
  def update
    @action = Posts::RetractForm.new(@post, current_user, publication_params)

    if @action.submit
      head :ok
    else
      head :unprocessable_content
    end
  end

  private

  def set_post
    @post = Post.find(params.require(:post_id))
  end

  def publication_params
    params.require(:publication).permit(:reason)
  end
end
