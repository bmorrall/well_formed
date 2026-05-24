# frozen_string_literal: true

module WellFormed
  class SimpleStruct
    module PoroInterface
      def id
        resource.respond_to?(:id) ? resource.id : nil
      end

      def persisted?
        resource.respond_to?(:persisted?) ? resource.persisted? : false
      end
    end

    include ActiveModel::Model
    include ActiveModel::Attributes
    include Translations
    include Persistence
    include NestedAttributes
    include Extensions
    prepend Initializer
    prepend PoroInterface

    private

    def perform
      raise NotImplementedError, "#{self.class} must implement #perform"
    end
  end
end
