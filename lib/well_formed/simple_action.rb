# frozen_string_literal: true

module WellFormed
  class SimpleAction
    include ActiveModel::Model
    include ActiveModel::Attributes
    include Translations
    include AttributeAssignment
    include Performer
    include NestedAttributes
    prepend Initializer
    include RecordIdentity
  end
end
