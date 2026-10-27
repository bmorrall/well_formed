# frozen_string_literal: true

RSpec.describe WellFormed do
  it "has a version number" do
    version = described_class::VERSION

    expect(version).not_to be_nil
  end

  describe WellFormed::ResourceForm do
    it "includes ActiveModel::Model" do
      ancestors = a_named_form_class.ancestors

      expect(ancestors).to include(ActiveModel::Model)
    end

    it "includes ActiveModel::Attributes" do
      ancestors = a_named_form_class.ancestors

      expect(ancestors).to include(ActiveModel::Attributes)
    end

    it "exposes resource and user readers" do
      resource = a_resource
      user = a_user

      form = a_named_form_class.new(resource, user)

      expect(form.resource).to be(resource)
      expect(form.user).to be(user)
    end

    it "assigns declared attributes from params" do
      form = a_named_form_class.new(a_resource, a_user, {name: "Alice"})

      expect(form.name).to eq("Alice")
    end

    it "defaults to empty params" do
      form = a_named_form_class.new(a_resource, a_user)

      expect(form.name).to be_nil
    end

    it "supports ActiveModel validations" do
      form = a_named_form_class.new(a_resource, a_user)

      expect(form).not_to be_valid
      expect(form.errors[:name]).to include("can't be blank")
    end
  end

  describe WellFormed::Initializer do
    it "raises when included instead of prepended" do
      initializer = described_class

      expect {
        Class.new { include initializer }
      }.to raise_error(ArgumentError, /must be prepended/)
    end

    it "calls after_initialize if defined" do
      form_class = stub_const("TestAfterInitForm", Class.new(WellFormed::ResourceForm) do
        attribute :name, :string

        def after_initialize
          self.name = "overridden"
        end
      end)

      form = form_class.new(a_resource, a_user)

      expect(form.name).to eq("overridden")
    end

    it "delegates id to resource" do
      form_class = stub_const("TestIdForm", Class.new(WellFormed::ResourceForm))

      form = form_class.new(a_resource(id: 42), a_user)

      expect(form.id).to eq(42)
    end

    it "delegates persisted? to resource" do
      form_class = stub_const("TestPersistedForm", Class.new(WellFormed::ResourceForm))

      form = form_class.new(a_resource(persisted?: true), a_user)

      expect(form.persisted?).to be(true)
    end

    it "delegates to_param to resource" do
      form_class = stub_const("TestToParamForm", Class.new(WellFormed::ResourceForm))

      form = form_class.new(a_resource(to_param: "42-my-article"), a_user)

      expect(form.to_param).to eq("42-my-article")
    end

    it "pre-populates attributes from the resource when no params given" do
      form_class = stub_const("TestDefaultsForm", Class.new(WellFormed::ResourceForm) do
        attribute :name, :string
      end)

      form = form_class.new(a_resource(name: "From Resource"), a_user)

      expect(form.name).to eq("From Resource")
    end

    it "lets params override resource defaults" do
      form_class = stub_const("TestOverrideForm", Class.new(WellFormed::ResourceForm) do
        attribute :name, :string
      end)

      form = form_class.new(a_resource(name: "From Resource"), a_user, {name: "From Params"})

      expect(form.name).to eq("From Params")
    end
  end

  def a_named_form_class
    stub_const("TestBaseForm", Class.new(WellFormed::ResourceForm) do
      attribute :name, :string
      validates :name, presence: true
    end)
  end

  def a_resource(**values)
    Class.new {
      values.each { |name, value| define_method(name) { value } }
    }.new
  end

  def a_user
    Object.new
  end
end
