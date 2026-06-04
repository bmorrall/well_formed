# frozen_string_literal: true

module WellFormed
  module Performer
    module ReservedMethodGuard  # :nodoc:
      def method_added(method_name)
        if %i[submit submit!].include?(method_name)
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

    module Abstract
      private

      def perform
        super
      end
    end

    def self.included(base)
      base.include(ActiveSupport::Callbacks)
      base.define_callbacks(:perform)
      base.define_callbacks(:perform_commit)
      base.extend(ClassMethods)
      base.prepend(Abstract)
      base.extend(ReservedMethodGuard)
    end

    module ClassMethods
      def before_perform(*args, &block)
        set_callback(:perform, :before, *args, &block)
      end

      def after_perform(*args, &block)
        set_callback(:perform, :after, *args, &block)
      end

      def after_perform_commit(*args, &block)
        require "active_record"
        if block
          set_callback(:perform_commit, :after) do
            ::ActiveRecord.after_all_transactions_commit { instance_exec(&block) }
          end
        else
          method_name = args.shift
          set_callback(:perform_commit, :after, *args) do
            ::ActiveRecord.after_all_transactions_commit { send(method_name) }
          end
        end
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
      run_callbacks(:perform_commit) if performed
      performed
    end

    private

    def perform
      raise NotImplementedError, "#{self.class} must implement #perform"
    end
  end
end
