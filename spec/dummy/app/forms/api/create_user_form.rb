# frozen_string_literal: true

module Api
  class CreateUserForm < WellFormed::ResourceForm
    resource_alias :user

    merge_model_errors

    attribute :name, :string
    attribute :email, :string

    validates :name, presence: true
    validates :email, presence: true
  end
end
