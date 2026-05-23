# frozen_string_literal: true

class Order < ApplicationRecord
  has_many :line_items, dependent: :destroy
  has_one :billing_address, dependent: :destroy

  accepts_nested_attributes_for :line_items
  accepts_nested_attributes_for :billing_address
end
