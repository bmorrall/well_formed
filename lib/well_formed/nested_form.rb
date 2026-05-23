# frozen_string_literal: true

module WellFormed
  # Minimal base class for anonymous nested-attribute forms built via
  # +nested_attributes_for+ / +nested_attribute_for+ blocks.
  #
  # Provides attribute definitions, validations, and collection helpers
  # without the persistence / transactional concerns of ResourceForm.
  # @api private
  class NestedForm < SimpleNestedForm
    include NestedAttributes
    prepend WithUser
  end
end
