# frozen_string_literal: true

class UpdatePostForm < WellFormed::ResourceForm
  resource_alias :post

  attribute :title, :string
  attribute :body, :string
  attribute :user_id, :integer

  validates :title, presence: true
  validates :body, presence: true

  collection_for :user_id, validate: true do
    User.all
  end

  private

  def perform
    assign_attributes_to(resource)
    resource.save
  end
end
