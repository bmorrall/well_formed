# frozen_string_literal: true

RSpec.describe WellFormed::SimpleResource do
  describe "constructor" do
    it "accepts (resource, params)" do
      form = a_create_thing_form_class.new(a_resource, {title: "Hello"})

      expect(form.title).to eq("Hello")
    end

    it "accepts (resource) with no params" do
      resource = a_resource

      form = a_create_thing_form_class.new(resource)

      expect(form.resource).to be(resource)
    end

    it "does not expose user" do
      form = a_create_thing_form_class.new(a_resource)

      expect(form).not_to respond_to(:user)
    end
  end

  describe "#resource" do
    it "returns the resource" do
      resource = a_resource
      form = a_create_thing_form_class.new(resource)

      expect(form.resource).to be(resource)
    end
  end

  describe "resource_defaults" do
    it "pre-fills attributes from the resource" do
      form = a_create_thing_form_class.new(a_resource(title: "Pre-filled"))

      expect(form.title).to eq("Pre-filled")
    end

    it "params override resource defaults" do
      form = a_create_thing_form_class.new(a_resource(title: "Default"), {title: "Override"})

      expect(form.title).to eq("Override")
    end
  end

  describe "#valid?" do
    it "returns true when attributes are valid" do
      form = a_create_thing_form_class.new(a_resource, {title: "Hello"})

      expect(form.valid?).to be(true)
    end

    it "returns false when attributes are invalid" do
      form = a_create_thing_form_class.new(a_resource)

      expect(form.valid?).to be(false)
    end
  end

  describe "#save" do
    it "assigns attributes to the resource and saves" do
      resource = a_resource
      form = a_create_thing_form_class.new(resource, {title: "Hello"})

      result = form.save

      expect(result).to be(true)
      expect(resource.assigned_attributes).to eq("title" => "Hello")
      expect(resource).to be_saved
    end

    it "returns false when invalid" do
      resource = a_resource
      form = a_create_thing_form_class.new(resource)

      result = form.save

      expect(result).to be(false)
      expect(resource).not_to be_saved
    end
  end

  describe "callbacks" do
    it "runs before_perform before persisting" do
      order = []
      resource = a_resource(on_save: -> { order << :save })
      form_class = a_create_thing_form_class
      form_class.before_perform { order << :before_perform }
      form = form_class.new(resource, {title: "Hello"})

      form.save

      expect(order).to eq([:before_perform, :save])
    end

    it "runs after_perform after persisting" do
      order = []
      resource = a_resource(on_save: -> { order << :save })
      form_class = a_create_thing_form_class
      form_class.after_perform { order << :after_perform }
      form = form_class.new(resource, {title: "Hello"})

      form.save

      expect(order).to eq([:save, :after_perform])
    end
  end

  describe "delegation" do
    it "delegates id to resource" do
      form = a_create_thing_form_class.new(a_resource(id: 42))

      expect(form.id).to eq(42)
    end

    it "delegates persisted? to resource" do
      form = a_create_thing_form_class.new(a_resource(persisted: true))

      expect(form.persisted?).to be(true)
    end
  end

  describe "collections" do
    it "supports collection_for" do
      form_class = stub_const("FormWithCollection", Class.new(described_class) do
        attribute :status, :string
        collection_for :status do
          ["draft", "published"]
        end
      end)
      form = form_class.new(a_resource)

      expect(form.collection_for_status).to eq(["draft", "published"])
    end
  end

  def a_create_thing_form_class
    stub_const("CreateThingForm", Class.new(described_class) do
      attribute :title, :string
      validates :title, presence: true

      private

      def perform
        assign_attributes_to(resource)
        resource.save
      end
    end)
  end

  def a_resource(title: nil, id: nil, persisted: false, on_save: nil)
    Class.new do
      attr_accessor :title
      attr_reader :assigned_attributes

      define_method(:id) { id }
      define_method(:persisted?) { persisted }
      define_method(:saved?) { !!@saved }

      define_method(:assign_attributes) do |attrs|
        @assigned_attributes = attrs
      end

      define_method(:save) do
        on_save&.call
        @saved = true
      end
    end.new.tap { |resource| resource.title = title }
  end
end
