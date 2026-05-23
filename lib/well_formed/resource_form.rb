# frozen_string_literal: true

module WellFormed
  class ResourceForm < SimpleResource
    prepend WithUser
  end
end
