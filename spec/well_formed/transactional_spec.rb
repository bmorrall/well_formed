# frozen_string_literal: true

RSpec.describe WellFormed::Transactional do
  let(:resource) do
    Class.new do
      attr_reader :assigned_attributes
      attr_writer :name, :email

      def assign_attributes(attrs)
        @assigned_attributes = attrs
      end

      def save
        true
      end
    end.new
  end

  let(:form_class) do
    stub_const("TransactionalForm", Class.new do
      include WellFormed

      attribute :name, :string
      attribute :email, :string

      validates :name, presence: true
    end)
  end

  describe ".after_save_commit" do
    it "registers an after_all_transactions_commit hook on success" do
      commit_block = nil
      allow(ActiveRecord).to receive(:after_all_transactions_commit) { |&b| commit_block = b }

      form_class.after_save_commit { "called" }
      form = form_class.new(resource, {name: "Alice"})
      form.save

      expect(commit_block).not_to be_nil
    end

    it "runs save_commit callbacks when the commit hook fires" do
      called = false
      commit_block = nil
      allow(ActiveRecord).to receive(:after_all_transactions_commit) { |&b| commit_block = b }

      form_class.after_save_commit { called = true }
      form_class.new(resource, {name: "Alice"}).save
      commit_block.call

      expect(called).to be(true)
    end

    it "fires after after_save when the commit hook is invoked" do
      order = []
      commit_block = nil
      allow(ActiveRecord).to receive(:after_all_transactions_commit) { |&b| commit_block = b }

      form_class.after_save { order << :after_save }
      form_class.after_save_commit { order << :after_save_commit }
      form_class.new(resource, {name: "Alice"}).save
      commit_block.call

      expect(order).to eq([:after_save, :after_save_commit])
    end

    it "does not register a hook when resource.save returns false" do
      allow(ActiveRecord).to receive(:after_all_transactions_commit)
      allow(resource).to receive(:save).and_return(false)
      form_class.new(resource, {name: "Alice"}).save
      expect(ActiveRecord).not_to have_received(:after_all_transactions_commit)
    end

    it "does not register a hook when invalid" do
      allow(ActiveRecord).to receive(:after_all_transactions_commit)
      form_class.new(resource).save
      expect(ActiveRecord).not_to have_received(:after_all_transactions_commit)
    end
  end

  describe ".save_within_transaction" do
    let(:ar_resource) do
      Class.new do
        attr_reader :assigned_attributes
        attr_writer :name, :email

        def assign_attributes(attrs)
          @assigned_attributes = attrs
        end

        def save
          true
        end

        def self.transaction(&block)
          @transaction_entered = true
          block.call
        rescue ActiveRecord::Rollback
          @transaction_rolled_back = true
        end

        def self.transaction_entered? = @transaction_entered
        def self.transaction_rolled_back? = @transaction_rolled_back
      end.new
    end

    let(:transaction_form_class) do
      stub_const("TransactionForm", Class.new do
        include WellFormed

        attribute :name, :string
        validates :name, presence: true
        save_within_transaction
      end)
    end

    it "runs the save inside a transaction" do
      form = transaction_form_class.new(ar_resource, {name: "Alice"})
      form.save
      expect(ar_resource.class.transaction_entered?).to be(true)
    end

    it "returns true on success" do
      form = transaction_form_class.new(ar_resource, {name: "Alice"})
      expect(form.save).to be(true)
    end

    it "rolls back and returns false when resource.save fails" do
      allow(ar_resource).to receive(:save).and_return(false)
      form = transaction_form_class.new(ar_resource, {name: "Alice"})
      expect(form.save).to be(false)
      expect(ar_resource.class.transaction_rolled_back?).to be(true)
    end
  end

  describe "WellFormed::Struct does not include Transactional" do
    it "does not have after_save_commit" do
      expect(WellFormed::Struct).not_to respond_to(:after_save_commit)
    end

    it "does not have save_within_transaction" do
      expect(WellFormed::Struct).not_to respond_to(:save_within_transaction)
    end
  end
end
