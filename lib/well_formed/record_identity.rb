# frozen_string_literal: true

module WellFormed
  module RecordIdentity
    module CreateBehavior
      def persisted? = false
      def id = nil
      def to_param = nil
    end

    module UpdateBehavior
      def persisted? = true
      def id = resource.respond_to?(:id) ? resource.id : nil
      delegate :to_param, to: :resource
    end

    module ClassMethods
      def create_action
        prepend CreateBehavior
      end

      def update_action
        prepend UpdateBehavior
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
      base.create_action
    end
  end
end
