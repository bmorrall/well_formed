# frozen_string_literal: true

module WellFormed
  module Persistence
    module ReservedMethodGuard  # :nodoc:
      def method_added(method_name)
        if %i[submit submit! save save!].include?(method_name)
          raise ArgumentError,
            "#{self} must not define ##{method_name} — it is reserved by WellFormed. " \
            "Use before_save/after_save callbacks instead."
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
      base.define_callbacks(:save)
      base.extend(ClassMethods)
      base.extend(ReservedMethodGuard)
    end

    module ClassMethods
      def before_save(*args, &block)
        set_callback(:save, :before, *args, &block)
      end

      def after_save(*args, &block)
        set_callback(:save, :after, *args, &block)
      end

      def merge_model_errors
        @merge_model_errors = true
      end

      def merge_model_errors?
        @merge_model_errors || false
      end
    end

    def save
      return false unless valid?

      result = nil
      catch(:abort) do
        assign_attributes_to(resource)
        run_callbacks(:save) do
          result = perform
          throw(:abort) unless result
        end
      end
      errors.add(:base, :could_not_be_saved, message: "could not be saved") if result == false && errors.empty?
      result || false
    end

    def save!
      save || raise(WellFormed::RecordInvalid.new(self))
    end

    def submit
      save && resource
    end

    private

    def perform
      result = resource.save
      errors.merge!(resource.errors) if !result && self.class.merge_model_errors?
      result
    end
  end
end
