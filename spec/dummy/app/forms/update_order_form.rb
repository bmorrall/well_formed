# frozen_string_literal: true

class UpdateOrderForm < WellFormed::ResourceForm
  resource_alias :order

  attribute :customer_name, :string

  validates :customer_name, presence: true

  nested_attributes_for :line_items do
    attribute :name, :string
    attribute :quantity, :integer

    validates :name, presence: true
    validates :quantity, numericality: {greater_than: 0}
  end

  nested_attribute_for :billing_address do
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
