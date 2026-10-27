# frozen_string_literal: true

require "active_record"

RSpec.describe WellFormed::Transactional do
  describe ".after_perform_commit" do
    it "registers an after_all_transactions_commit hook on success" do
      commit_block = nil
      allow(ActiveRecord).to receive(:after_all_transactions_commit) { |&b| commit_block = b }
      form_class = a_transactional_form_class
      form_class.after_perform_commit { "called" }
      form = form_class.new(a_resource, {name: "Alice"})

      form.save

      expect(commit_block).not_to be_nil
    end

    it "runs save_commit callbacks when the commit hook fires" do
      called = false
      commit_block = nil
      allow(ActiveRecord).to receive(:after_all_transactions_commit) { |&b| commit_block = b }
      form_class = a_transactional_form_class
      form_class.after_perform_commit { called = true }
      form = form_class.new(a_resource, {name: "Alice"})
      form.save

      commit_block.call

      expect(called).to be(true)
    end

    it "fires after after_perform when the commit hook is invoked" do
      order = []
      commit_block = nil
      allow(ActiveRecord).to receive(:after_all_transactions_commit) { |&b| commit_block = b }
      form_class = a_transactional_form_class
      form_class.after_perform { order << :after_perform }
      form_class.after_perform_commit { order << :after_perform_commit }
      form = form_class.new(a_resource, {name: "Alice"})
      form.save

      commit_block.call

      expect(order).to eq([:after_perform, :after_perform_commit])
    end

    it "does not register a hook when resource.save returns false" do
      allow(ActiveRecord).to receive(:after_all_transactions_commit)
      form = a_transactional_form_class.new(a_resource(save_result: false), {name: "Alice"})

      form.save

      expect(ActiveRecord).not_to have_received(:after_all_transactions_commit)
    end

    it "does not register a hook when invalid" do
      allow(ActiveRecord).to receive(:after_all_transactions_commit)
      form = a_transactional_form_class.new(a_resource)

      form.save

      expect(ActiveRecord).not_to have_received(:after_all_transactions_commit)
    end

    it "calls a named method inside the commit hook" do
      called = false
      commit_block = nil
      allow(ActiveRecord).to receive(:after_all_transactions_commit) { |&b| commit_block = b }
      form_class = a_transactional_form_class
      form_class.define_method(:notify) { called = true }
      form_class.after_perform_commit :notify
      form = form_class.new(a_resource, {name: "Alice"})
      form.save

      commit_block.call

      expect(called).to be(true)
    end
  end

  describe ".save_within_transaction" do
    it "runs the save inside a transaction" do
      resource = a_resource
      form = a_transaction_form_class.new(resource, {name: "Alice"})

      form.save

      expect(resource.class.transaction_entered?).to be(true)
    end

    it "returns true on success" do
      form = a_transaction_form_class.new(a_resource, {name: "Alice"})

      expect(form.save).to be(true)
    end

    it "rolls back and returns false when resource.save fails" do
      resource = a_resource(save_result: false)
      form = a_transaction_form_class.new(resource, {name: "Alice"})

      result = form.save

      expect(result).to be(false)
      expect(resource.class.transaction_rolled_back?).to be(true)
    end
  end

  def a_transactional_form_class
    stub_const("TransactionalForm", Class.new do
      include WellFormed

      attribute :name, :string
      attribute :email, :string

      validates :name, presence: true

      private

      def perform
        resource.save
      end
    end)
  end

  def a_transaction_form_class
    stub_const("TransactionForm", Class.new do
      include WellFormed

      attribute :name, :string
      validates :name, presence: true
      save_within_transaction

      private

      def perform
        resource.save
      end
    end)
  end

  def a_resource(save_result: true)
    Class.new do
      attr_reader :assigned_attributes
      attr_writer :name, :email

      def self.transaction(&block)
        @transaction_entered = true
        block.call
      rescue ActiveRecord::Rollback
        @transaction_rolled_back = true
      end

      def self.transaction_entered? = @transaction_entered
      def self.transaction_rolled_back? = @transaction_rolled_back

      def assign_attributes(attrs)
        @assigned_attributes = attrs
      end

      define_method(:save) { save_result }
    end.new
  end
end
