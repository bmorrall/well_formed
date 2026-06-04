# frozen_string_literal: true

class CreateOrderFlatAddressForm < WellFormed::ResourceForm
  resource_alias :order

  attribute :customer_name, :string

  validates :customer_name, presence: true

  delegated_attribute_for :billing_address do
    attribute :street, :string
    attribute :city, :string
    attribute :postcode, :string

    validates :street, presence: true
    validates :city, presence: true
    validates :postcode, presence: true
  end

  private

  def perform
    assign_attributes_to(resource)
    resource.save
  end
end
