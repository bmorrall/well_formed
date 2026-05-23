# frozen_string_literal: true

module Api
  class UpdatePostForm < WellFormed::ResourceForm
    resource_alias :post

    attribute :title, :string
    attribute :user_code  # accepts a user integer id, resolves to code string

    validates :title, presence: true

    collection_for :user_code, validate: :id, resolves_to: :code do
      User.all
    end
  end
end
