# frozen_string_literal: true

module WellFormed
  class Struct < SimpleStruct
    prepend WithUser
  end
end
