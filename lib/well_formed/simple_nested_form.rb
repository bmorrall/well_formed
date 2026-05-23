# frozen_string_literal: true

module WellFormed
  class SimpleNestedForm
    include ActiveModel::Model
    include ActiveModel::Attributes
    include Translations
    include Collections
    include NestedAttributes
    prepend Initializer
  end
end
