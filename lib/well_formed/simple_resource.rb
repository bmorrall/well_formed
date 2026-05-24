# frozen_string_literal: true

module WellFormed
  class SimpleResource
    include ActiveModel::Model
    include ActiveModel::Attributes
    include Translations
    include Persistence
    include Transactional
    include Collections
    include NestedAttributes
    include Extensions
    prepend Initializer
  end
end
