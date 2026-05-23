# frozen_string_literal: true

module WellFormed
  module Persistence
    def self.included(base)
      base.include(ActiveSupport::Callbacks)
      base.include(AttributeAssignment)
      base.define_callbacks(:save)
      base.extend(ClassMethods)
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
