# frozen_string_literal: true

module WellFormed
  module Transactional
    def self.included(base)
      base.define_callbacks(:save_commit)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def after_save_commit(*args, &block)
        require "active_record"
        if block
          set_callback(:save_commit, :after) do
            ::ActiveRecord.after_all_transactions_commit { instance_exec(&block) }
          end
        else
          method_name = args.shift
          set_callback(:save_commit, :after, *args) do
            ::ActiveRecord.after_all_transactions_commit { send(method_name) }
          end
        end
      end

      def save_within_transaction
        require "active_record"
        set_callback(:save, :around) do |form, block|
          saved = false
          form.resource.class.transaction do
            catch(:abort) do
              block.call
              saved = true
            end
            raise ActiveRecord::Rollback unless saved
          end
          throw(:abort) unless saved
        end
      end
    end

    def save
      result = super
      run_callbacks(:save_commit) if result
      result || false
    end
  end
end
