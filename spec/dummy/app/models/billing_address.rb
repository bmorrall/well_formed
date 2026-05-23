# frozen_string_literal: true

class BillingAddress < ApplicationRecord
  belongs_to :order
end
