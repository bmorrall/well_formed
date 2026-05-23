# frozen_string_literal: true

class CreatePostForm < WellFormed::ResourceForm
  resource_alias :post

  attribute :title, :string
  attribute :body, :string
  attribute :user_id, :integer

  validates :title, presence: true
  validates :body, presence: true

  collection_for :user_id, validate: true do
    User.all
  end
end
