# frozen_string_literal: true

module WellFormed
  module Performer
    module Abstract
      private

      def perform
        super
      end
    end

    def self.included(base)
      base.include(ActiveSupport::Callbacks)
      base.define_callbacks(:perform)
      base.extend(ClassMethods)
      base.prepend(Abstract)
    end

    module ClassMethods
      def before_perform(*args, &block)
        set_callback(:perform, :before, *args, &block)
      end

      def after_perform(*args, &block)
        set_callback(:perform, :after, *args, &block)
      end

      def inherited(subclass)
        super
        subclass.prepend(Abstract)
      end
    end

    def submit!
      submit || raise(WellFormed::RecordInvalid.new(self))
    end

    def submit
      return false unless valid?

      performed = false
      run_callbacks(:perform) do
        perform
        performed = true
      end
      errors.add(:base, :could_not_be_performed, message: "could not be performed") if !performed && errors.empty?
      performed
    end

    private

    def perform
      raise NotImplementedError, "#{self.class} must implement #perform"
    end
  end
end
