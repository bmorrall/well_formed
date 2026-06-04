# frozen_string_literal: true

class CreateSubscriptionForm < WellFormed::ActionForm
  resource_alias :subscription

  attribute :email, :string
  attribute :name, :string

  validates :email, presence: true
  validates :name, presence: true

  private

  def perform
    subscription.email = email
    subscription.name = name
    subscription.subscribe!
    true
  end
end
