# frozen_string_literal: true

RSpec.describe WellFormed::DryTypes do
  it "has a version number" do
    expect(WellFormed::DryTypes::VERSION).not_to be_nil
  end

  describe "auto-include via Extensions" do
    let(:form_class) do
      stub_const("TestForm", Class.new(WellFormed::SimpleResource))
    end

    it "is included automatically in SimpleResource subclasses" do
      expect(form_class.ancestors).to include(WellFormed::DryTypes)
    end
  end

  describe "#dry_attribute coercion" do
    let(:resource) { double("resource", save: true) }
    let(:user) { double("user") }

    let(:form_class) do
      stub_const("CoercionForm", Class.new(WellFormed::ResourceForm) do
        dry_attribute :amount, Types::Params::Decimal
        dry_attribute :count, Types::Params::Integer
      end)
    end

    it "coerces string params to the declared type before validation" do
      form = form_class.new(resource, user, {amount: "42.5", count: "3"})
      form.valid?

      expect(form.amount).to eq(BigDecimal("42.5"))
      expect(form.count).to eq(3)
    end

    it "stores the coerced value, not the raw string" do
      form = form_class.new(resource, user, {amount: "10.00"})
      form.valid?

      expect(form.amount).to be_a(BigDecimal)
    end

    it "is valid when all coercions succeed" do
      form = form_class.new(resource, user, {amount: "9.99", count: "1"})

      expect(form).to be_valid
    end
  end

  describe "coercion failures" do
    let(:resource) { double("resource") }
    let(:user) { double("user") }

    let(:form_class) do
      stub_const("FailureForm", Class.new(WellFormed::ResourceForm) do
        dry_attribute :amount, Types::Params::Decimal
        dry_attribute :count, Types::Params::Integer
      end)
    end

    it "adds an error on the attribute when coercion fails" do
      form = form_class.new(resource, user, {amount: "not-a-number"})
      form.valid?

      expect(form.errors[:amount]).to include('"not-a-number" cannot be coerced to decimal')
    end

    it "collects all coercion errors in a single valid? call" do
      form = form_class.new(resource, user, {amount: "bad", count: "also-bad"})
      form.valid?

      expect(form.errors[:amount]).to include('"bad" cannot be coerced to decimal')
      expect(form.errors[:count]).to include('invalid value for Integer(): "also-bad"')
    end

    it "leaves the raw value on the attribute when coercion fails" do
      form = form_class.new(resource, user, {amount: "bad"})
      form.valid?

      expect(form.amount).to eq("bad")
    end
  end

  describe "nil and optional values" do
    let(:resource) { double("resource") }
    let(:user) { double("user") }

    it "passes nil through a strict type and raises a coercion error" do
      form_class = stub_const("StrictNilForm", Class.new(WellFormed::ResourceForm) do
        dry_attribute :amount, Types::Strict::Decimal
      end)

      form = form_class.new(resource, user, {amount: nil})
      form.valid?

      expect(form.errors[:amount]).not_to be_empty
    end

    it "accepts nil when the type is optional" do
      form_class = stub_const("OptionalForm", Class.new(WellFormed::ResourceForm) do
        dry_attribute :amount, Types::Params::Decimal.optional
      end)

      form = form_class.new(resource, user, {amount: nil})
      form.valid?

      expect(form.errors[:amount]).to be_empty
      expect(form.amount).to be_nil
    end
  end

  describe "message: option" do
    let(:resource) { double("resource") }
    let(:user) { double("user") }

    it "uses an I18n symbol message on coercion failure" do
      form_class = stub_const("SymbolMessageForm", Class.new(WellFormed::ResourceForm) do
        dry_attribute :amount, Types::Params::Decimal, message: :invalid
      end)

      form = form_class.new(resource, user, {amount: "bad"})
      form.valid?

      expect(form.errors[:amount]).to include("is invalid")
    end

    it "uses a string message on coercion failure" do
      form_class = stub_const("StringMessageForm", Class.new(WellFormed::ResourceForm) do
        dry_attribute :amount, Types::Params::Decimal, message: "must be a number"
      end)

      form = form_class.new(resource, user, {amount: "bad"})
      form.valid?

      expect(form.errors[:amount]).to include("must be a number")
    end

    it "falls back to the dry-types error message when no message is given" do
      form_class = stub_const("DefaultMessageForm", Class.new(WellFormed::ResourceForm) do
        dry_attribute :amount, Types::Params::Decimal
      end)

      form = form_class.new(resource, user, {amount: "bad"})
      form.valid?

      expect(form.errors[:amount].first).not_to be_empty
    end
  end

  describe "subclass inheritance" do
    let(:resource) { double("resource", save: true) }
    let(:user) { double("user") }

    let(:parent_class) do
      stub_const("DryParentForm", Class.new(WellFormed::ResourceForm) do
        dry_attribute :amount, Types::Params::Decimal
      end)
    end

    let(:child_class) do
      stub_const("DryChildForm", Class.new(parent_class) do
        dry_attribute :count, Types::Params::Integer
      end)
    end

    it "child inherits the parent's dry_attribute declarations" do
      form = child_class.new(resource, user, {amount: "5.0", count: "3"})
      form.valid?

      expect(form.amount).to eq(BigDecimal("5.0"))
      expect(form.count).to eq(3)
    end

    it "parent is unaffected by the child's dry_attribute declarations" do
      form = parent_class.new(resource, user, {amount: "5.0"})

      expect(form).not_to respond_to(:count)
    end

    it "collects errors from both parent and child attributes" do
      form = child_class.new(resource, user, {amount: "bad", count: "bad"})
      form.valid?

      expect(form.errors[:amount]).not_to be_empty
      expect(form.errors[:count]).not_to be_empty
    end
  end

  describe "constrained types" do
    let(:resource) { double("resource") }
    let(:user) { double("user") }

    let(:form_class) do
      stub_const("ConstrainedForm", Class.new(WellFormed::ResourceForm) do
        dry_attribute :score, Types::Params::Integer.constrained(gteq: 0, lteq: 100)
      end)
    end

    it "accepts a value within the constraint" do
      form = form_class.new(resource, user, {score: "50"})
      form.valid?

      expect(form.errors[:score]).to be_empty
      expect(form.score).to eq(50)
    end

    it "adds an error when the constraint is violated" do
      form = form_class.new(resource, user, {score: "150"})
      form.valid?

      expect(form.errors[:score]).not_to be_empty
    end
  end
end
