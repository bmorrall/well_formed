# frozen_string_literal: true

RSpec.describe WellFormed do
  it "has a version number" do
    expect(WellFormed::VERSION).not_to be nil
  end

  let(:resource) { double("resource") }
  let(:user) { double("user") }

  describe "when inherited" do
    let(:form_class) do
      stub_const("TestForm", Class.new(WellFormed::ResourceForm) do
        attribute :name, :string
        validates :name, presence: true
      end)
    end

    it "includes ActiveModel::Model" do
      expect(form_class.ancestors).to include(ActiveModel::Model)
    end

    it "includes ActiveModel::Attributes" do
      expect(form_class.ancestors).to include(ActiveModel::Attributes)
    end

    it "exposes resource and user readers" do
      form = form_class.new(resource, user)
      expect(form.resource).to eq(resource)
      expect(form.user).to eq(user)
    end

    it "assigns declared attributes from params" do
      form = form_class.new(resource, user, {name: "Alice"})
      expect(form.name).to eq("Alice")
    end

    it "defaults to empty params" do
      form = form_class.new(resource, user)
      expect(form.name).to be_nil
    end

    it "supports ActiveModel validations" do
      form = form_class.new(resource, user)
      expect(form).not_to be_valid
      expect(form.errors[:name]).to include("can't be blank")
    end
  end

  describe WellFormed::Initializer do
    it "raises when included instead of prepended" do
      expect {
        Class.new { include WellFormed::Initializer }
      }.to raise_error(ArgumentError, /must be prepended/)
    end

    it "calls after_initialize if defined" do
      form_class = stub_const("TestAfterInitForm", Class.new(WellFormed::ResourceForm) do
        attribute :name, :string

        def after_initialize
          self.name = "overridden"
        end
      end)

      form = form_class.new(resource, user)
      expect(form.name).to eq("overridden")
    end

    it "delegates id to resource" do
      allow(resource).to receive(:id).and_return(42)
      form = stub_const("TestIdForm", Class.new(WellFormed::ResourceForm))
        .new(resource, user)
      expect(form.id).to eq(42)
    end

    it "delegates persisted? to resource" do
      allow(resource).to receive(:persisted?).and_return(true)
      form = stub_const("TestPersistedForm", Class.new(WellFormed::ResourceForm))
        .new(resource, user)
      expect(form.persisted?).to be(true)
    end

    it "delegates to_param to resource" do
      allow(resource).to receive(:to_param).and_return("42-my-article")
      form = stub_const("TestToParamForm", Class.new(WellFormed::ResourceForm))
        .new(resource, user)
      expect(form.to_param).to eq("42-my-article")
    end

    it "pre-populates attributes from the resource when no params given" do
      resource_with_name = Class.new {
        attr_reader :name
        def initialize(n) = (@name = n)
      }.new("From Resource")
      form = stub_const("TestDefaultsForm", Class.new(WellFormed::ResourceForm) do
        attribute :name, :string
      end).new(resource_with_name, user)
      expect(form.name).to eq("From Resource")
    end

    it "params override resource defaults" do
      resource_with_name = Class.new {
        attr_reader :name
        def initialize(n) = (@name = n)
      }.new("From Resource")
      form = stub_const("TestOverrideForm", Class.new(WellFormed::ResourceForm) do
        attribute :name, :string
      end).new(resource_with_name, user, {name: "From Params"})
      expect(form.name).to eq("From Params")
    end
  end

  describe WellFormed::ResourceForm do
    let(:form_class) do
      stub_const("TestBaseForm", Class.new(WellFormed::ResourceForm) do
        attribute :name, :string
        validates :name, presence: true
      end)
    end

    it "includes ActiveModel::Model" do
      expect(form_class.ancestors).to include(ActiveModel::Model)
    end

    it "includes ActiveModel::Attributes" do
      expect(form_class.ancestors).to include(ActiveModel::Attributes)
    end

    it "exposes resource and user readers" do
      form = form_class.new(resource, user)
      expect(form.resource).to eq(resource)
      expect(form.user).to eq(user)
    end

    it "assigns declared attributes from params" do
      form = form_class.new(resource, user, {name: "Bob"})
      expect(form.name).to eq("Bob")
    end

    it "defaults to empty params" do
      form = form_class.new(resource, user)
      expect(form.name).to be_nil
    end

    it "supports ActiveModel validations" do
      form = form_class.new(resource, user)
      expect(form).not_to be_valid
      expect(form.errors[:name]).to include("can't be blank")
    end
  end
end
