# frozen_string_literal: true

module WellFormed
  module Persistence
    module ReservedMethodGuard  # :nodoc:
      def method_added(method_name)
        if %i[save save! submit submit!].include?(method_name)
          raise ArgumentError,
            "#{self} must not define ##{method_name} — it is reserved by WellFormed. " \
            "Use before_perform/after_perform callbacks instead."
        end
        super
      end

      def inherited(subclass)
        super
        subclass.extend(ReservedMethodGuard)
      end
    end

    def self.included(base)
      base.include(ActiveSupport::Callbacks)
      base.include(AttributeAssignment)
      base.define_callbacks(:perform)
      base.extend(ClassMethods)
      base.extend(ReservedMethodGuard)
    end

    module ClassMethods
      def before_perform(*args, &block)
        set_callback(:perform, :before, *args, &block)
      end

      def after_perform(*args, &block)
        set_callback(:perform, :after, *args, &block)
      end
    end

    def save
      return false unless valid?

      result = nil
      catch(:abort) do
        run_callbacks(:perform) do
          result = perform
          throw(:abort) unless result
        end
      end
      errors.add(:base, :could_not_be_saved, message: "could not be saved") if !result && errors.empty?
      !!result
    end

    def save!
      save || raise(WellFormed::RecordInvalid.new(self))
    end

    def submit
      save && resource
    end

    private

    def merge_errors(model)
      errors.merge!(model.errors)
    end

    def perform
      raise NotImplementedError, "#{self.class} must implement #perform"
    end
  end
end
