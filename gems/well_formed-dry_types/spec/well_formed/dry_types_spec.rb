# frozen_string_literal: true

RSpec.describe WellFormed::DryTypes do
  it "has a version number" do
    expect(described_class::VERSION).not_to be_nil
  end

  describe "auto-include via Extensions" do
    it "is included automatically in SimpleResource subclasses" do
      form_class = stub_const("TestForm", Class.new(WellFormed::SimpleResource))

      expect(form_class.ancestors).to include(described_class)
    end
  end

  describe "#dry_attribute coercion" do
    it "coerces string params to the declared type before validation" do
      form = a_coercion_form_class.new(a_resource, a_user, {amount: "42.5", count: "3"})

      form.valid?

      expect(form.amount).to eq(BigDecimal("42.5"))
      expect(form.count).to eq(3)
    end

    it "stores the coerced value, not the raw string" do
      form = a_coercion_form_class.new(a_resource, a_user, {amount: "10.00"})

      form.valid?

      expect(form.amount).to be_a(BigDecimal)
    end

    it "is valid when all coercions succeed" do
      form = a_coercion_form_class.new(a_resource, a_user, {amount: "9.99", count: "1"})

      expect(form).to be_valid
    end
  end

  describe "coercion failures" do
    it "adds an error on the attribute when coercion fails" do
      form = a_coercion_form_class.new(a_resource, a_user, {amount: "not-a-number"})

      form.valid?

      expect(form.errors[:amount]).to include('"not-a-number" cannot be coerced to decimal')
    end

    it "collects all coercion errors in a single valid? call" do
      form = a_coercion_form_class.new(a_resource, a_user, {amount: "bad", count: "also-bad"})

      form.valid?

      expect(form.errors[:amount]).to include('"bad" cannot be coerced to decimal')
      expect(form.errors[:count]).to include('invalid value for Integer(): "also-bad"')
    end

    it "leaves the raw value on the attribute when coercion fails" do
      form = a_coercion_form_class.new(a_resource, a_user, {amount: "bad"})

      form.valid?

      expect(form.amount).to eq("bad")
    end
  end

  describe "nil and optional values" do
    it "passes nil through a strict type and raises a coercion error" do
      form_class = stub_const("StrictNilForm", Class.new(WellFormed::ResourceForm) do
        dry_attribute :amount, Types::Strict::Decimal
      end)
      form = form_class.new(a_resource, a_user, {amount: nil})

      form.valid?

      expect(form.errors[:amount]).to eq(["nil violates constraints (type?(BigDecimal, nil) failed)"])
    end

    it "accepts nil when the type is optional" do
      form_class = stub_const("OptionalForm", Class.new(WellFormed::ResourceForm) do
        dry_attribute :amount, Types::Params::Decimal.optional
      end)
      form = form_class.new(a_resource, a_user, {amount: nil})

      form.valid?

      expect(form.errors[:amount]).to be_empty
      expect(form.amount).to be_nil
    end
  end

  describe "message: option" do
    it "uses an I18n symbol message on coercion failure" do
      form_class = stub_const("SymbolMessageForm", Class.new(WellFormed::ResourceForm) do
        dry_attribute :amount, Types::Params::Decimal, message: :invalid
      end)
      form = form_class.new(a_resource, a_user, {amount: "bad"})

      form.valid?

      expect(form.errors[:amount]).to include("is invalid")
    end

    it "uses a string message on coercion failure" do
      form_class = stub_const("StringMessageForm", Class.new(WellFormed::ResourceForm) do
        dry_attribute :amount, Types::Params::Decimal, message: "must be a number"
      end)
      form = form_class.new(a_resource, a_user, {amount: "bad"})

      form.valid?

      expect(form.errors[:amount]).to include("must be a number")
    end

    it "falls back to the dry-types error message when no message is given" do
      form_class = stub_const("DefaultMessageForm", Class.new(WellFormed::ResourceForm) do
        dry_attribute :amount, Types::Params::Decimal
      end)
      form = form_class.new(a_resource, a_user, {amount: "bad"})

      form.valid?

      expect(form.errors[:amount]).to eq(['"bad" cannot be coerced to decimal'])
    end
  end

  describe "subclass inheritance" do
    it "child inherits the parent's dry_attribute declarations" do
      child_class = a_child_form_class(a_parent_form_class)
      form = child_class.new(a_resource, a_user, {amount: "5.0", count: "3"})

      form.valid?

      expect(form.amount).to eq(BigDecimal("5.0"))
      expect(form.count).to eq(3)
    end

    it "parent is unaffected by the child's dry_attribute declarations" do
      parent_class = a_parent_form_class
      a_child_form_class(parent_class)

      form = parent_class.new(a_resource, a_user, {amount: "5.0"})

      expect(form).not_to respond_to(:count)
    end

    it "collects errors from both parent and child attributes" do
      child_class = a_child_form_class(a_parent_form_class)
      form = child_class.new(a_resource, a_user, {amount: "bad", count: "bad"})

      form.valid?

      expect(form.errors[:amount]).to eq(['"bad" cannot be coerced to decimal'])
      expect(form.errors[:count]).to eq(['invalid value for Integer(): "bad"'])
    end
  end

  describe "constrained types" do
    it "accepts a value within the constraint" do
      form = a_constrained_form_class.new(a_resource, a_user, {score: "50"})

      form.valid?

      expect(form.errors[:score]).to be_empty
      expect(form.score).to eq(50)
    end

    it "adds an error when the constraint is violated" do
      form = a_constrained_form_class.new(a_resource, a_user, {score: "150"})

      form.valid?

      expect(form.errors[:score]).to eq(['"150" violates constraints (lteq?(100, 150) failed)'])
    end
  end

  def a_coercion_form_class
    stub_const("CoercionForm", Class.new(WellFormed::ResourceForm) do
      dry_attribute :amount, Types::Params::Decimal
      dry_attribute :count, Types::Params::Integer
    end)
  end

  def a_parent_form_class
    stub_const("DryParentForm", Class.new(WellFormed::ResourceForm) do
      dry_attribute :amount, Types::Params::Decimal
    end)
  end

  def a_child_form_class(parent_class)
    stub_const("DryChildForm", Class.new(parent_class) do
      dry_attribute :count, Types::Params::Integer
    end)
  end

  def a_constrained_form_class
    stub_const("ConstrainedForm", Class.new(WellFormed::ResourceForm) do
      dry_attribute :score, Types::Params::Integer.constrained(gteq: 0, lteq: 100)
    end)
  end

  def a_resource = Object.new

  def a_user = Object.new
end
