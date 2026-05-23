# frozen_string_literal: true

module WellFormed
  class Error < StandardError; end
  class UnmatchedAttributesError < Error; end

  class RecordInvalid < Error
    attr_reader :record

    def initialize(record)
      @record = record
      messages = record.errors.full_messages
      super(messages.empty? ? "Record invalid" : "Validation failed: #{messages.join(", ")}")
    end
  end
end
