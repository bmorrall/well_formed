# frozen_string_literal: true

module Api
  class CreateUserForm < WellFormed::ResourceForm
    resource_alias :user

    attribute :name, :string
    attribute :email, :string

    validates :name, presence: true
    validates :email, presence: true

    private

    def perform
      assign_attributes_to(resource)
      result = resource.save
      merge_errors(resource) unless result
      result
    end
  end
end
