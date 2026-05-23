# frozen_string_literal: true

require "active_record"

module WellFormed
  module Transactional
    def self.included(base)
      base.define_callbacks(:save_commit)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def after_save_commit(*args, &block)
        set_callback(:save_commit, :after, *args, &block)
      end

      def save_within_transaction
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
      ::ActiveRecord.after_all_transactions_commit { run_callbacks(:save_commit) } if result
      result || false
    end
  end
end
