# frozen_string_literal: true

class UpdateUserProfileForm < WellFormed::ResourceForm

  resource_alias :user

  attribute :name, :string
  attribute :email, :string

  validates :name, presence: true
  validates :email, presence: true
end
