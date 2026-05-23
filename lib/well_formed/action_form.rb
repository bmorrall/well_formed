# frozen_string_literal: true

module WellFormed
  class ActionForm < SimpleAction
    prepend WithUser
  end
end
