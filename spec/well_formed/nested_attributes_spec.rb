# frozen_string_literal: true

RSpec.describe WellFormed::NestedAttributes do
  let(:line_item_form_class) do
    stub_const("LineItemForm", Class.new do
      include WellFormed

      attribute :name, :string
      attribute :quantity, :integer

      validates :name, presence: true
      validates :quantity, numericality: {greater_than: 0}
    end)
  end

  let(:form_class) do
    line_item_form_class
    stub_const("OrderForm", Class.new do
      include WellFormed

      attribute :customer_name, :string

      validates :customer_name, presence: true

      nested_attributes_for :line_items, LineItemForm
    end)
  end

  let(:resource) do
    Class.new do
      attr_accessor :customer_name
      attr_reader :line_items_attributes_assigned

      def line_items_attributes=(attrs)
        @line_items_attributes_assigned = attrs
      end

      def line_items
        []
      end

      def assign_attributes(attrs)
        attrs.each { |k, v| public_send(:"#{k}=", v) }
      end

      def save
        true
      end
    end.new
  end

  describe ".nested_attributes_for" do
    it "defines an attribute reader for the association name" do
      form = form_class.new(resource, {customer_name: "Alice"})
      expect(form).to respond_to(:line_items)
    end

    it "defines a name_attributes= setter" do
      expect(form_class.new(resource, {})).to respond_to(:line_items_attributes=)
    end

    it "defines a name= setter (API style, no suffix)" do
      expect(form_class.new(resource, {})).to respond_to(:line_items=)
    end

    it "raises ArgumentError when both a form_class and a block are given" do
      klass = line_item_form_class
      expect {
        Class.new do
          include WellFormed

          nested_attributes_for :line_items, klass do
            attribute :name, :string
          end
        end
      }.to raise_error(ArgumentError)
    end
  end

  describe "inline block (anonymous form class)" do
    let(:inline_form_class) do
      line_item_form_class
      stub_const("InlineOrderForm", Class.new do
        include WellFormed

        attribute :customer_name, :string

        nested_attributes_for :line_items do
          attribute :name, :string
          validates :name, presence: true
        end
      end)
    end

    it "registers an anonymous form class for the nested association" do
      expect(inline_form_class.registered_nested_attributes[:line_items][:form_class]).to be_a(Class)
    end

    it "assigns a synthetic model_name based on the association name" do
      klass = inline_form_class.registered_nested_attributes[:line_items][:form_class]
      expect(klass.model_name.name).to eq("LineItem")
    end

    it "validates using the inline block's validators" do
      form = inline_form_class.new(resource, {
        customer_name: "Alice",
        line_items_attributes: [{name: ""}]
      })
      expect(form.valid?).to be(false)
      expect(form.errors.map { |e| e.attribute.to_s }).to include("line_items[0].name")
    end

    it "passes when the inline block validators are satisfied" do
      form = inline_form_class.new(resource, {
        customer_name: "Alice",
        line_items_attributes: [{name: "Widget"}]
      })
      expect(form.valid?).to be(true)
    end
  end

  describe "#valid?" do
    context "when no nested attributes are provided" do
      it "validates only the parent form" do
        form = form_class.new(resource, {customer_name: "Alice"})
        expect(form.valid?).to be(true)
      end

      it "returns false when the parent is invalid" do
        form = form_class.new(resource, {customer_name: ""})
        expect(form.valid?).to be(false)
      end
    end

    context "when all nested forms are valid" do
      it "returns true" do
        form = form_class.new(resource, {
          customer_name: "Alice",
          line_items_attributes: [{name: "Widget", quantity: 2}]
        })
        expect(form.valid?).to be(true)
      end
    end

    context "when a nested form is invalid" do
      subject(:form) do
        form_class.new(resource, {
          customer_name: "Alice",
          line_items_attributes: [{name: "", quantity: 2}]
        })
      end

      it "returns false" do
        expect(form.valid?).to be(false)
      end

      it "adds indexed errors from the nested form to the parent" do
        form.valid?
        error_attributes = form.errors.map { |e| e.attribute.to_s }
        expect(error_attributes).to include("line_items[0].name")
      end

      it "includes the nested form error message" do
        form.valid?
        error = form.errors.find { |e| e.attribute.to_s == "line_items[0].name" }
        expect(error.message).to eq("can't be blank")
      end
    end

    context "when both parent and nested form are invalid" do
      it "returns false and includes errors from both" do
        form = form_class.new(resource, {
          customer_name: "",
          line_items_attributes: [{name: "", quantity: 2}]
        })
        form.valid?
        expect(form.errors[:customer_name]).not_to be_empty
        expect(form.errors.map { |e| e.attribute.to_s }).to include("line_items[0].name")
      end
    end

    context "when a nested form error has a non-Symbol type" do
      it "propagates the error message directly (collection)" do
        fake_error = double("error", type: 42, message: "is wrong", attribute: :name, options: {})
        fake_nested_form = double("nested_form")
        allow(fake_nested_form).to receive(:valid?).and_return(false)
        allow(fake_nested_form).to receive(:errors).and_return([fake_error])

        form = form_class.new(resource, {customer_name: "Alice"})
        form.instance_variable_set(:@line_items, [fake_nested_form])
        form.valid?

        expect(form.errors.map { |e| e.attribute.to_s }).to include("line_items[0].name")
      end
    end

    context "when nested attrs are provided via name= (API style)" do
      it "validates the nested forms" do
        form = form_class.new(resource, {customer_name: "Alice"})
        form.line_items = [{name: "", quantity: 2}]
        expect(form.valid?).to be(false)
        expect(form.errors.map { |e| e.attribute.to_s }).to include("line_items[0].name")
      end
    end

    context "with _destroy flag" do
      it "skips validation for items marked with _destroy: true" do
        form = form_class.new(resource, {
          customer_name: "Alice",
          line_items_attributes: [{name: "", quantity: 2, _destroy: true}]
        })
        expect(form.valid?).to be(true)
      end

      it "skips validation for items marked with _destroy: '1'" do
        form = form_class.new(resource, {
          customer_name: "Alice",
          line_items_attributes: [{name: "", quantity: 2, _destroy: "1"}]
        })
        expect(form.valid?).to be(true)
      end

      it "validates items where _destroy is false" do
        form = form_class.new(resource, {
          customer_name: "Alice",
          line_items_attributes: [{name: "", quantity: 2, _destroy: false}]
        })
        expect(form.valid?).to be(false)
      end
    end

    context "with multiple nested items" do
      it "reports errors per item index" do
        form = form_class.new(resource, {
          customer_name: "Alice",
          line_items_attributes: [
            {name: "Widget", quantity: 2},
            {name: "", quantity: 0}
          ]
        })
        form.valid?
        error_attributes = form.errors.map { |e| e.attribute.to_s }
        expect(error_attributes).not_to include("line_items[0].name")
        expect(error_attributes).to include("line_items[1].name")
        expect(error_attributes).to include("line_items[1].quantity")
      end
    end

    context "when attributes are submitted as a hash with string integer keys (HTML form encoding)" do
      it "builds nested form instances" do
        form = form_class.new(resource, {
          customer_name: "Alice",
          line_items_attributes: {"0" => {name: "Widget", quantity: 2}}
        })
        expect(form.line_items.length).to eq(1)
        expect(form.line_items.first.name).to eq("Widget")
      end

      it "returns true when nested forms are valid" do
        form = form_class.new(resource, {
          customer_name: "Alice",
          line_items_attributes: {"0" => {name: "Widget", quantity: 2}}
        })
        expect(form.valid?).to be(true)
      end

      it "returns false when a nested form is invalid" do
        form = form_class.new(resource, {
          customer_name: "Alice",
          line_items_attributes: {"0" => {name: "", quantity: 0}}
        })
        expect(form.valid?).to be(false)
        expect(form.errors.map { |e| e.attribute.to_s }).to include("line_items[0].name")
      end

      it "reports errors at the correct index for multiple items" do
        form = form_class.new(resource, {
          customer_name: "Alice",
          line_items_attributes: {
            "0" => {name: "Widget", quantity: 2},
            "1" => {name: "", quantity: 0}
          }
        })
        form.valid?
        error_attributes = form.errors.map { |e| e.attribute.to_s }
        expect(error_attributes).not_to include("line_items[0].name")
        expect(error_attributes).to include("line_items[1].name")
      end

      it "skips items marked with _destroy" do
        form = form_class.new(resource, {
          customer_name: "Alice",
          line_items_attributes: {"0" => {name: "", quantity: 0, _destroy: "1"}}
        })
        expect(form.valid?).to be(true)
      end
    end
  end

  describe "#line_items" do
    it "returns an array of nested form instances" do
      form = form_class.new(resource, {
        customer_name: "Alice",
        line_items_attributes: [{name: "Widget", quantity: 2}]
      })
      expect(form.line_items).to be_a(Array)
      expect(form.line_items.length).to eq(1)
      expect(form.line_items.first).to be_a(LineItemForm)
    end

    it "populates nested form attributes from the provided params" do
      form = form_class.new(resource, {
        customer_name: "Alice",
        line_items_attributes: [{name: "Widget", quantity: 3}]
      })
      expect(form.line_items.first.name).to eq("Widget")
      expect(form.line_items.first.quantity).to eq(3)
    end

    it "excludes items marked for destruction" do
      form = form_class.new(resource, {
        customer_name: "Alice",
        line_items_attributes: [
          {name: "Widget", quantity: 2},
          {name: "Gizmo", quantity: 1, _destroy: "1"}
        ]
      })
      expect(form.line_items.length).to eq(1)
      expect(form.line_items.first.name).to eq("Widget")
    end

    it "returns an empty array when no attributes are provided" do
      form = form_class.new(resource, {customer_name: "Alice"})
      expect(form.line_items).to eq([])
    end

    it "lazy-loads from the resource when no setter has been called" do
      line_item = double("line_item", name: "Widget", quantity: 2)
      allow(resource).to receive(:line_items).and_return([line_item])

      form = form_class.new(resource, {customer_name: "Alice"})
      expect(form.line_items.length).to eq(1)
      expect(form.line_items.first).to be_a(LineItemForm)
      expect(form.line_items.first.name).to eq("Widget")
    end

    it "returns an empty array when the resource does not respond to the association" do
      minimal_resource = double("minimal_resource")
      allow(minimal_resource).to receive(:respond_to?).and_return(false)

      form = form_class.new(minimal_resource, {customer_name: "Alice"})
      expect(form.line_items).to eq([])
    end
  end

  describe "#save" do
    it "delegates nested attributes to the resource immediately via the setter" do
      form_class.new(resource, {
        customer_name: "Alice",
        line_items_attributes: [{name: "Widget", quantity: 2}]
      })
      expect(resource.line_items_attributes_assigned).to eq([{name: "Widget", quantity: 2}])
    end

    it "passes the original attributes including _destroy through to the resource" do
      form = form_class.new(resource, {
        customer_name: "Alice",
        line_items_attributes: [{name: "Widget", quantity: 2, _destroy: "1"}]
      })
      form.save
      raw = resource.line_items_attributes_assigned
      expect(raw.first).to include(_destroy: "1")
    end

    it "does not save when a nested form is invalid" do
      form = form_class.new(resource, {
        customer_name: "Alice",
        line_items_attributes: [{name: "", quantity: 2}]
      })
      expect(form.save).to be(false)
    end
  end

  describe "_find_collection_resource rescue" do
    it "returns nil and builds the nested form without a backing record when the collection fetch raises" do
      allow(resource).to receive(:line_items).and_raise(StandardError)

      form = form_class.new(resource, {
        customer_name: "Alice",
        line_items_attributes: [{"id" => "1", "name" => "Widget", "quantity" => "2"}]
      })
      expect(form.line_items.length).to eq(1)
      expect(form.line_items.first.name).to eq("Widget")
    end
  end

  describe "singular nested form (nested_attribute_for)" do
    let(:address_form_class) do
      stub_const("AddressForm", Class.new do
        include WellFormed

        attribute :street, :string
        validates :street, presence: true
      end)
    end

    let(:singular_form_class) do
      address_form_class
      stub_const("UserForm", Class.new do
        include WellFormed

        attribute :name, :string

        nested_attribute_for :address, AddressForm
      end)
    end

    let(:address_record) { double("address", street: nil) }
    let(:singular_resource) do
      r = double("resource")
      allow(r).to receive(:respond_to?).and_return(false)
      allow(r).to receive(:respond_to?).with(:address).and_return(true)
      allow(r).to receive(:respond_to?).with(:address_attributes=).and_return(true)
      allow(r).to receive(:respond_to?).with(:assign_attributes).and_return(true)
      allow(r).to receive(:address).and_return(address_record)
      allow(r).to receive(:assign_attributes)
      allow(r).to receive(:address_attributes=)
      allow(r).to receive(:save).and_return(true)
      r
    end

    it "builds a single nested form instance" do
      form = singular_form_class.new(singular_resource, {
        name: "Bob",
        address_attributes: {street: "123 Main St"}
      })
      expect(form.address).to be_a(AddressForm)
    end

    it "returns false when the singular nested form is invalid" do
      form = singular_form_class.new(singular_resource, {
        name: "Bob",
        address_attributes: {street: ""}
      })
      expect(form.valid?).to be(false)
    end

    it "adds errors with the association name prefix" do
      form = singular_form_class.new(singular_resource, {
        name: "Bob",
        address_attributes: {street: ""}
      })
      form.valid?
      error_attributes = form.errors.map { |e| e.attribute.to_s }
      expect(error_attributes).to include("address.street")
    end

    it "returns true when the singular nested form is valid" do
      form = singular_form_class.new(singular_resource, {
        name: "Bob",
        address_attributes: {street: "123 Main St"}
      })
      expect(form.valid?).to be(true)
    end

    it "accepts params via the name= setter (API style)" do
      form = singular_form_class.new(singular_resource, {})
      form.address = {street: ""}
      expect(form.valid?).to be(false)
      expect(form.errors.map { |e| e.attribute.to_s }).to include("address.street")
    end

    it "lazy-loads from the resource when no address_attributes are provided" do
      form = singular_form_class.new(singular_resource, {name: "Bob"})
      expect(form.address).to be_a(AddressForm)
      expect(form.address.street).to be_nil
    end

    context "when a singular nested form error has a non-Symbol type" do
      it "propagates the error message directly (singular)" do
        fake_error = double("error", type: 42, message: "is wrong", attribute: :street, options: {})
        fake_address_form = double("address_form")
        allow(fake_address_form).to receive(:valid?).and_return(false)
        allow(fake_address_form).to receive(:errors).and_return([fake_error])

        form = singular_form_class.new(singular_resource, {name: "Bob"})
        form.instance_variable_set(:@address, fake_address_form)
        form.valid?

        expect(form.errors.map { |e| e.attribute.to_s }).to include("address.street")
      end
    end
  end

  describe "inheritance" do
    it "includes nested attributes from the parent class" do
      klass = line_item_form_class
      base_class = Class.new do
        include WellFormed

        nested_attributes_for :line_items, klass
      end

      child_class = Class.new(base_class)

      expect(child_class.registered_nested_attributes).to include(:line_items)
    end

    it "allows child class to add its own nested attributes" do
      tag_form_class = stub_const("TagForm", Class.new do
        include WellFormed

        attribute :label, :string
        validates :label, presence: true
      end)

      line_items_klass = line_item_form_class
      base_class = Class.new do
        include WellFormed

        nested_attributes_for :line_items, line_items_klass
      end

      child_class = Class.new(base_class) do
        nested_attributes_for :tags, tag_form_class
      end

      expect(child_class.registered_nested_attributes.keys).to include(:line_items, :tags)
      expect(base_class.registered_nested_attributes.keys).to eq([:line_items])
    end
  end

  describe "multi-level nested attributes" do
    let(:line_item_resource) do
      Class.new do
        def dimensions = []

        def dimensions_attributes=(attrs); end
      end.new
    end

    let(:deep_resource) do
      li = line_item_resource
      Class.new do
        def line_items = []

        def line_items_attributes=(attrs); end

        def assign_attributes(attrs)
          attrs.each { |k, v| public_send(:"#{k}=", v) }
        end

        def save = true
      end.new
    end

    context "without user (include WellFormed)" do
      let(:form_class) do
        stub_const("DeepOrderForm", Class.new do
          include WellFormed

          attribute :customer_name, :string

          nested_attributes_for :line_items do
            attribute :name, :string

            nested_attributes_for :dimensions do
              attribute :width, :integer
              validates :width, numericality: {greater_than: 0}
            end
          end
        end)
      end

      it "registers nested attributes on the generated nested form class" do
        line_item_klass = form_class.registered_nested_attributes[:line_items][:form_class]
        expect(line_item_klass.registered_nested_attributes).to have_key(:dimensions)
      end

      it "propagates deep validation errors to the top-level form" do
        form = form_class.new(deep_resource, {
          customer_name: "Alice",
          line_items_attributes: [
            {name: "Widget", dimensions_attributes: [{width: -1}]}
          ]
        })
        expect(form.valid?).to be(false)
        expect(form.errors.map { |e| e.attribute.to_s }).to include("line_items[0].dimensions[0].width")
      end

      it "is valid when all levels are valid" do
        form = form_class.new(deep_resource, {
          customer_name: "Alice",
          line_items_attributes: [
            {name: "Widget", dimensions_attributes: [{width: 10}]}
          ]
        })
        expect(form.valid?).to be(true)
      end

      it "accepts the no-suffix (API) style at every level" do
        form = form_class.new(deep_resource, {
          customer_name: "Alice",
          line_items: [
            {name: "Widget", dimensions: [{width: -1}]}
          ]
        })
        expect(form.valid?).to be(false)
        expect(form.errors.map { |e| e.attribute.to_s }).to include("line_items[0].dimensions[0].width")
      end
    end

    context "with user (ResourceForm)" do
      let(:form_class) do
        stub_const("DeepOrderFormWithUser", Class.new(WellFormed::ResourceForm) do
          attribute :customer_name, :string

          nested_attributes_for :line_items do
            attribute :name, :string

            nested_attributes_for :dimensions do
              attribute :width, :integer
              validates :width, numericality: {greater_than: 0}
            end
          end
        end)
      end

      let(:user) { double("user") }

      it "registers nested attributes on the generated nested form class" do
        line_item_klass = form_class.registered_nested_attributes[:line_items][:form_class]
        expect(line_item_klass.registered_nested_attributes).to have_key(:dimensions)
      end

      it "propagates deep validation errors to the top-level form" do
        form = form_class.new(deep_resource, user, {
          customer_name: "Alice",
          line_items_attributes: [
            {name: "Widget", dimensions_attributes: [{width: -1}]}
          ]
        })
        expect(form.valid?).to be(false)
        expect(form.errors.map { |e| e.attribute.to_s }).to include("line_items[0].dimensions[0].width")
      end

      it "is valid when all levels are valid" do
        form = form_class.new(deep_resource, user, {
          customer_name: "Alice",
          line_items_attributes: [
            {name: "Widget", dimensions_attributes: [{width: 10}]}
          ]
        })
        expect(form.valid?).to be(true)
      end

      it "accepts the no-suffix (API) style at every level" do
        form = form_class.new(deep_resource, user, {
          customer_name: "Alice",
          line_items: [
            {name: "Widget", dimensions: [{width: -1}]}
          ]
        })
        expect(form.valid?).to be(false)
        expect(form.errors.map { |e| e.attribute.to_s }).to include("line_items[0].dimensions[0].width")
      end
    end
  end
end
