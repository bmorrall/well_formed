# frozen_string_literal: true

class User < ApplicationRecord
  validates :email, format: {with: /\A[^@\s]+@[^@\s]+\z/, message: :invalid}
end
