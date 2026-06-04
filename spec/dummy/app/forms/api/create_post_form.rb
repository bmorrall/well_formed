# frozen_string_literal: true

module Api
  class CreatePostForm < WellFormed::ResourceForm
    resource_alias :post

    attribute :title, :string
    attribute :user_id  # accepts a user code string, resolves to integer id

    validates :title, presence: true

    collection_for :user_id, validate: :code, resolves_to: :id do
      User.all
    end

    private

    def perform
      assign_attributes_to(resource)
      resource.save
    end
  end
end
