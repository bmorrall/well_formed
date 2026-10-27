# frozen_string_literal: true

RSpec.describe WellFormed::NestedAttributes do
  describe ".nested_attributes_for" do
    it "defines an attribute reader for the association name" do
      form = an_order_form_class.new(an_order_resource, {customer_name: "Alice"})

      expect(form).to respond_to(:line_items)
    end

    it "defines a name_attributes= setter" do
      form = an_order_form_class.new(an_order_resource, {})

      expect(form).to respond_to(:line_items_attributes=)
    end

    it "defines a name= setter (API style, no suffix)" do
      form = an_order_form_class.new(an_order_resource, {})

      expect(form).to respond_to(:line_items=)
    end

    it "raises ArgumentError when both a form_class and a block are given" do
      line_item_form_class = a_line_item_form_class

      expect {
        Class.new do
          include WellFormed

          nested_attributes_for :line_items, line_item_form_class do
            attribute :name, :string
          end
        end
      }.to raise_error(ArgumentError, /not both/)
    end

    it "raises ArgumentError when neither a form_class nor a block is given" do
      expect {
        Class.new do
          include WellFormed

          nested_attributes_for :line_items
        end
      }.to raise_error(ArgumentError, /A form_class or block is required/)
    end
  end

  describe "inline block (anonymous form class)" do
    it "registers an anonymous form class for the nested association" do
      form_class = an_inline_order_form_class

      nested_form_class = form_class.registered_nested_attributes[:line_items][:form_class]

      expect(nested_form_class).to be_a(Class)
    end

    it "assigns a synthetic model_name based on the association name" do
      form_class = an_inline_order_form_class

      nested_form_class = form_class.registered_nested_attributes[:line_items][:form_class]

      expect(nested_form_class.model_name.name).to eq("LineItem")
    end

    it "validates using the inline block's validators" do
      form = an_inline_order_form_class.new(an_order_resource, {
        customer_name: "Alice",
        line_items_attributes: [{name: ""}]
      })

      expect(form.valid?).to be(false)
      expect(form.errors[:"line_items[0].name"]).to include("can't be blank")
    end

    it "passes when the inline block validators are satisfied" do
      form = an_inline_order_form_class.new(an_order_resource, {
        customer_name: "Alice",
        line_items_attributes: [{name: "Widget"}]
      })

      expect(form.valid?).to be(true)
    end
  end

  describe "#valid?" do
    it "validates only the parent form when no nested attributes are provided" do
      form = an_order_form_class.new(an_order_resource, {customer_name: "Alice"})

      expect(form.valid?).to be(true)
    end

    it "returns false when the parent is invalid and no nested attributes are provided" do
      form = an_order_form_class.new(an_order_resource, {customer_name: ""})

      expect(form.valid?).to be(false)
    end

    it "returns true when all nested forms are valid" do
      form = an_order_form_class.new(an_order_resource, {
        customer_name: "Alice",
        line_items_attributes: [{name: "Widget", quantity: 2}]
      })

      expect(form.valid?).to be(true)
    end

    context "when a nested form is invalid" do
      subject(:form) do
        an_order_form_class.new(an_order_resource, {
          customer_name: "Alice",
          line_items_attributes: [{name: "", quantity: 2}]
        })
      end

      it "returns false" do
        expect(form.valid?).to be(false)
      end

      it "adds indexed errors from the nested form to the parent" do
        form.valid?

        expect(form.errors.attribute_names).to include(:"line_items[0].name")
      end

      it "includes the nested form error message" do
        form.valid?

        expect(form.errors[:"line_items[0].name"]).to eq(["can't be blank"])
      end
    end

    it "returns false and includes errors from both when the parent and a nested form are invalid" do
      form = an_order_form_class.new(an_order_resource, {
        customer_name: "",
        line_items_attributes: [{name: "", quantity: 2}]
      })

      form.valid?

      expect(form.errors[:customer_name]).to include("can't be blank")
      expect(form.errors[:"line_items[0].name"]).to include("can't be blank")
    end

    it "copies a nested error added with a message string (non-Symbol type) onto the indexed attribute" do
      form_class = Class.new do
        include WellFormed

        nested_attributes_for :line_items do
          attribute :name, :string

          validate { errors.add(:name, "is wrong") }
        end
      end
      form = form_class.new(an_order_resource, {line_items_attributes: [{name: "Widget"}]})

      expect(form.valid?).to be(false)
      expect(form.errors[:"line_items[0].name"]).to eq(["is wrong"])
    end

    it "validates the nested forms when nested attrs are provided via name= (API style)" do
      form = an_order_form_class.new(an_order_resource, {customer_name: "Alice"})

      form.line_items = [{name: "", quantity: 2}]

      expect(form.valid?).to be(false)
      expect(form.errors[:"line_items[0].name"]).to include("can't be blank")
    end

    it "skips validation for items marked with _destroy: true" do
      form = an_order_form_class.new(an_order_resource, {
        customer_name: "Alice",
        line_items_attributes: [{name: "", quantity: 2, _destroy: true}]
      })

      expect(form.valid?).to be(true)
    end

    it "skips validation for items marked with _destroy: '1'" do
      form = an_order_form_class.new(an_order_resource, {
        customer_name: "Alice",
        line_items_attributes: [{name: "", quantity: 2, _destroy: "1"}]
      })

      expect(form.valid?).to be(true)
    end

    it "validates items where _destroy is false" do
      form = an_order_form_class.new(an_order_resource, {
        customer_name: "Alice",
        line_items_attributes: [{name: "", quantity: 2, _destroy: false}]
      })

      expect(form.valid?).to be(false)
    end

    it "reports errors at the submitted index when earlier items are destroyed" do
      form = an_order_form_class.new(an_order_resource, {
        customer_name: "Alice",
        line_items_attributes: [
          {name: "Gizmo", quantity: 1, _destroy: "1"},
          {name: "", quantity: 2}
        ]
      })

      form.valid?

      expect(form.errors.attribute_names).to include(:"line_items[1].name")
      expect(form.errors.attribute_names).not_to include(:"line_items[0].name")
    end

    it "reports errors per item index for multiple nested items" do
      form = an_order_form_class.new(an_order_resource, {
        customer_name: "Alice",
        line_items_attributes: [
          {name: "Widget", quantity: 2},
          {name: "", quantity: 0}
        ]
      })

      form.valid?

      expect(form.errors.attribute_names).not_to include(:"line_items[0].name")
      expect(form.errors[:"line_items[1].name"]).to include("can't be blank")
      expect(form.errors[:"line_items[1].quantity"]).to include("must be greater than 0")
    end

    it "builds nested form instances from a hash with string integer keys (HTML form encoding)" do
      form = an_order_form_class.new(an_order_resource, {
        customer_name: "Alice",
        line_items_attributes: {"0" => {name: "Widget", quantity: 2}}
      })

      expect(form.line_items.length).to eq(1)
      expect(form.line_items.first.name).to eq("Widget")
    end

    it "returns true when nested forms submitted as a string-keyed hash are valid" do
      form = an_order_form_class.new(an_order_resource, {
        customer_name: "Alice",
        line_items_attributes: {"0" => {name: "Widget", quantity: 2}}
      })

      expect(form.valid?).to be(true)
    end

    it "returns false when a nested form submitted as a string-keyed hash is invalid" do
      form = an_order_form_class.new(an_order_resource, {
        customer_name: "Alice",
        line_items_attributes: {"0" => {name: "", quantity: 0}}
      })

      expect(form.valid?).to be(false)
      expect(form.errors[:"line_items[0].name"]).to include("can't be blank")
    end

    it "reports errors at the correct index for multiple items submitted as a string-keyed hash" do
      form = an_order_form_class.new(an_order_resource, {
        customer_name: "Alice",
        line_items_attributes: {
          "0" => {name: "Widget", quantity: 2},
          "1" => {name: "", quantity: 0}
        }
      })

      form.valid?

      expect(form.errors.attribute_names).not_to include(:"line_items[0].name")
      expect(form.errors.attribute_names).to include(:"line_items[1].name")
    end

    it "skips items marked with _destroy submitted as a string-keyed hash" do
      form = an_order_form_class.new(an_order_resource, {
        customer_name: "Alice",
        line_items_attributes: {"0" => {name: "", quantity: 0, _destroy: "1"}}
      })

      expect(form.valid?).to be(true)
    end

    it "reports errors at the submitted index when earlier items submitted as a string-keyed hash are destroyed" do
      form = an_order_form_class.new(an_order_resource, {
        customer_name: "Alice",
        line_items_attributes: {
          "0" => {name: "Gizmo", quantity: 1, _destroy: "1"},
          "1" => {name: "", quantity: 0}
        }
      })

      form.valid?

      expect(form.errors.attribute_names).to include(:"line_items[1].name")
      expect(form.errors.attribute_names).not_to include(:"line_items[0].name")
    end
  end

  describe "#line_items" do
    it "returns an array of nested form instances" do
      form = an_order_form_class.new(an_order_resource, {
        customer_name: "Alice",
        line_items_attributes: [{name: "Widget", quantity: 2}]
      })

      expect(form.line_items).to be_a(Array)
      expect(form.line_items.length).to eq(1)
      expect(form.line_items.first).to be_a(LineItemForm)
    end

    it "populates nested form attributes from the provided params" do
      form = an_order_form_class.new(an_order_resource, {
        customer_name: "Alice",
        line_items_attributes: [{name: "Widget", quantity: 3}]
      })

      expect(form.line_items.first.name).to eq("Widget")
      expect(form.line_items.first.quantity).to eq(3)
    end

    it "excludes items marked for destruction" do
      form = an_order_form_class.new(an_order_resource, {
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
      form = an_order_form_class.new(an_order_resource, {customer_name: "Alice"})

      expect(form.line_items).to eq([])
    end

    it "lazy-loads from the resource when no setter has been called" do
      resource = an_order_resource(line_items: [a_line_item(name: "Widget", quantity: 2)])

      form = an_order_form_class.new(resource, {customer_name: "Alice"})

      expect(form.line_items.length).to eq(1)
      expect(form.line_items.first).to be_a(LineItemForm)
      expect(form.line_items.first.name).to eq("Widget")
      expect(form.line_items.first.quantity).to eq(2)
    end

    it "returns an empty array when the resource does not respond to the association" do
      resource = Object.new

      form = an_order_form_class.new(resource, {customer_name: "Alice"})

      expect(form.line_items).to eq([])
    end

    it "drops blank entries when lazy-loading from the resource" do
      resource = an_order_resource(line_items: [nil, "", {}])

      form = an_order_form_class.new(resource, {customer_name: "Alice"})

      expect(form.line_items).to eq([])
    end

    it "keeps present entries alongside blank ones when lazy-loading from the resource" do
      resource = an_order_resource(line_items: [nil, a_line_item(name: "Widget", quantity: 2), {}])

      form = an_order_form_class.new(resource, {customer_name: "Alice"})

      expect(form.line_items.length).to eq(1)
      expect(form.line_items.first.name).to eq("Widget")
    end

    context "with a presence validation when the resource has only blank entries" do
      let(:required_form_class) do
        line_item_form_class = a_line_item_form_class

        stub_const("RequiredOrderForm", Class.new do
          include WellFormed

          nested_attributes_for :line_items, line_item_form_class

          validates :line_items, presence: true
        end)
      end

      let(:resource) { an_order_resource(line_items: [{}]) }

      it "fails a presence validation on the parent" do
        form = required_form_class.new(resource, {})

        expect(form.valid?).to be(false)
        expect(form.errors[:line_items]).to include("can't be blank")
      end

      it "still builds and validates nested forms assigned through the setter" do
        form = required_form_class.new(resource, {})

        form.line_items = [{name: ""}]

        expect(form.line_items.first).to be_a(LineItemForm)
        expect(form.valid?).to be(false)
        expect(form.errors[:"line_items[0].name"]).to include("can't be blank")

        form.line_items = [{name: "Widget", quantity: 1}]

        expect(form.valid?).to be(true)
      end
    end
  end

  describe "#line_items_attributes=" do
    it "delegates nested attributes to the resource immediately" do
      resource = an_order_resource
      line_items_attributes = [{name: "Widget", quantity: 2}]

      an_order_form_class.new(resource, {customer_name: "Alice", line_items_attributes:})

      expect(resource.line_items_attributes_assigned).to eq(line_items_attributes)
    end
  end

  describe "#save" do
    it "passes the original attributes including _destroy through to the resource" do
      resource = an_order_resource
      form = an_order_form_class.new(resource, {
        customer_name: "Alice",
        line_items_attributes: [{name: "Widget", quantity: 2, _destroy: "1"}]
      })

      form.save

      expect(resource.line_items_attributes_assigned.first).to include(_destroy: "1")
    end

    it "does not save when a nested form is invalid" do
      form = an_order_form_class.new(an_order_resource, {
        customer_name: "Alice",
        line_items_attributes: [{name: "", quantity: 2}]
      })

      expect(form.save).to be(false)
    end
  end

  describe "_find_collection_resource rescue" do
    it "builds the nested form without a backing record when the collection fetch raises" do
      resource = an_order_resource
      allow(resource).to receive(:line_items).and_raise(StandardError)

      form = an_order_form_class.new(resource, {
        customer_name: "Alice",
        line_items_attributes: [{"id" => "1", "name" => "Widget", "quantity" => "2"}]
      })

      expect(form.line_items.length).to eq(1)
      expect(form.line_items.first.name).to eq("Widget")
    end
  end

  describe "singular nested form (nested_attribute_for)" do
    it "builds a single nested form instance" do
      form = a_user_form_class.new(a_user_resource, {
        name: "Bob",
        address_attributes: {street: "123 Main St"}
      })

      expect(form.address).to be_a(AddressForm)
    end

    it "returns false when the singular nested form is invalid" do
      form = a_user_form_class.new(a_user_resource, {
        name: "Bob",
        address_attributes: {street: ""}
      })

      expect(form.valid?).to be(false)
    end

    it "adds errors with the association name prefix" do
      form = a_user_form_class.new(a_user_resource, {
        name: "Bob",
        address_attributes: {street: ""}
      })

      form.valid?

      expect(form.errors[:"address.street"]).to include("can't be blank")
    end

    it "returns true when the singular nested form is valid" do
      form = a_user_form_class.new(a_user_resource, {
        name: "Bob",
        address_attributes: {street: "123 Main St"}
      })

      expect(form.valid?).to be(true)
    end

    it "accepts params via the name= setter (API style)" do
      form = a_user_form_class.new(a_user_resource, {})

      form.address = {street: ""}

      expect(form.valid?).to be(false)
      expect(form.errors[:"address.street"]).to include("can't be blank")
    end

    it "lazy-loads from the resource when no address_attributes are provided" do
      resource = a_user_resource(address: an_address(street: "123 Main St"))

      form = a_user_form_class.new(resource, {name: "Bob"})

      expect(form.address).to be_a(AddressForm)
      expect(form.address.street).to eq("123 Main St")
    end

    it "returns nil when lazy-loading an empty hash from the resource" do
      resource = a_user_resource(address: {})

      form = a_user_form_class.new(resource, {name: "Bob"})

      expect(form.address).to be_nil
    end

    it "returns nil when lazy-loading an empty string from the resource" do
      resource = a_user_resource(address: "")

      form = a_user_form_class.new(resource, {name: "Bob"})

      expect(form.address).to be_nil
    end

    it "copies a nested error added with a message string (non-Symbol type) onto the prefixed attribute" do
      form_class = Class.new do
        include WellFormed

        nested_attribute_for :address do
          attribute :street, :string

          validate { errors.add(:street, "is wrong") }
        end
      end
      form = form_class.new(a_user_resource, {address_attributes: {street: "123 Main St"}})

      expect(form.valid?).to be(false)
      expect(form.errors[:"address.street"]).to eq(["is wrong"])
    end

    context "with a presence validation when the resource has a blank value" do
      let(:required_form_class) do
        address_form_class = an_address_form_class

        stub_const("RequiredUserForm", Class.new do
          include WellFormed

          nested_attribute_for :address, address_form_class

          validates :address, presence: true
        end)
      end

      let(:resource) { a_user_resource(address: {}) }

      it "fails a presence validation on the parent" do
        form = required_form_class.new(resource, {})

        expect(form.valid?).to be(false)
        expect(form.errors[:address]).to include("can't be blank")
      end

      it "still builds and validates a nested form assigned through the setter" do
        form = required_form_class.new(resource, {})

        form.address = {street: ""}

        expect(form.address).to be_a(AddressForm)
        expect(form.valid?).to be(false)
        expect(form.errors[:"address.street"]).to include("can't be blank")

        form.address = {street: "123 Main St"}

        expect(form.valid?).to be(true)
      end
    end
  end

  describe "inheritance" do
    it "includes nested attributes from the parent class" do
      line_item_form_class = a_line_item_form_class
      base_class = Class.new do
        include WellFormed

        nested_attributes_for :line_items, line_item_form_class
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
      line_item_form_class = a_line_item_form_class
      base_class = Class.new do
        include WellFormed

        nested_attributes_for :line_items, line_item_form_class
      end

      child_class = Class.new(base_class) do
        nested_attributes_for :tags, tag_form_class
      end

      expect(child_class.registered_nested_attributes.keys).to include(:line_items, :tags)
      expect(base_class.registered_nested_attributes.keys).to eq([:line_items])
    end
  end

  describe "multi-level nested attributes" do
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
        line_item_form_class = form_class.registered_nested_attributes[:line_items][:form_class]

        expect(line_item_form_class.registered_nested_attributes).to have_key(:dimensions)
      end

      it "propagates deep validation errors to the top-level form" do
        form = form_class.new(a_deep_order_resource, {
          customer_name: "Alice",
          line_items_attributes: [
            {name: "Widget", dimensions_attributes: [{width: -1}]}
          ]
        })

        expect(form.valid?).to be(false)
        expect(form.errors[:"line_items[0].dimensions[0].width"]).to include("must be greater than 0")
      end

      it "is valid when all levels are valid" do
        form = form_class.new(a_deep_order_resource, {
          customer_name: "Alice",
          line_items_attributes: [
            {name: "Widget", dimensions_attributes: [{width: 10}]}
          ]
        })

        expect(form.valid?).to be(true)
      end

      it "accepts the no-suffix (API) style at every level" do
        form = form_class.new(a_deep_order_resource, {
          customer_name: "Alice",
          line_items: [
            {name: "Widget", dimensions: [{width: -1}]}
          ]
        })

        expect(form.valid?).to be(false)
        expect(form.errors[:"line_items[0].dimensions[0].width"]).to include("must be greater than 0")
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

      let(:user) { Object.new }

      it "registers nested attributes on the generated nested form class" do
        line_item_form_class = form_class.registered_nested_attributes[:line_items][:form_class]

        expect(line_item_form_class.registered_nested_attributes).to have_key(:dimensions)
      end

      it "propagates deep validation errors to the top-level form" do
        form = form_class.new(a_deep_order_resource, user, {
          customer_name: "Alice",
          line_items_attributes: [
            {name: "Widget", dimensions_attributes: [{width: -1}]}
          ]
        })

        expect(form.valid?).to be(false)
        expect(form.errors[:"line_items[0].dimensions[0].width"]).to include("must be greater than 0")
      end

      it "is valid when all levels are valid" do
        form = form_class.new(a_deep_order_resource, user, {
          customer_name: "Alice",
          line_items_attributes: [
            {name: "Widget", dimensions_attributes: [{width: 10}]}
          ]
        })

        expect(form.valid?).to be(true)
      end

      it "accepts the no-suffix (API) style at every level" do
        form = form_class.new(a_deep_order_resource, user, {
          customer_name: "Alice",
          line_items: [
            {name: "Widget", dimensions: [{width: -1}]}
          ]
        })

        expect(form.valid?).to be(false)
        expect(form.errors[:"line_items[0].dimensions[0].width"]).to include("must be greater than 0")
      end
    end
  end

  def a_line_item_form_class
    stub_const("LineItemForm", Class.new do
      include WellFormed

      attribute :name, :string
      attribute :quantity, :integer

      validates :name, presence: true
      validates :quantity, numericality: {greater_than: 0}
    end)
  end

  def an_order_form_class
    line_item_form_class = a_line_item_form_class

    stub_const("OrderForm", Class.new do
      include WellFormed

      attribute :customer_name, :string

      validates :customer_name, presence: true

      nested_attributes_for :line_items, line_item_form_class

      private

      def perform
        resource.save
      end
    end)
  end

  def an_inline_order_form_class
    stub_const("InlineOrderForm", Class.new do
      include WellFormed

      attribute :customer_name, :string

      nested_attributes_for :line_items do
        attribute :name, :string
        validates :name, presence: true
      end
    end)
  end

  def an_address_form_class
    stub_const("AddressForm", Class.new do
      include WellFormed

      attribute :street, :string
      validates :street, presence: true
    end)
  end

  def a_user_form_class
    address_form_class = an_address_form_class

    stub_const("UserForm", Class.new do
      include WellFormed

      attribute :name, :string

      nested_attribute_for :address, address_form_class
    end)
  end

  def an_order_resource(line_items: [])
    Class.new do
      attr_accessor :customer_name
      attr_reader :line_items, :line_items_attributes_assigned

      def initialize(line_items)
        @line_items = line_items
      end

      def line_items_attributes=(attrs)
        @line_items_attributes_assigned = attrs
      end

      def assign_attributes(attrs)
        attrs.each { |k, v| public_send(:"#{k}=", v) }
      end

      def save
        true
      end
    end.new(line_items)
  end

  def a_user_resource(address: an_address(street: nil))
    Class.new do
      attr_reader :address

      def initialize(address)
        @address = address
      end

      def address_attributes=(attrs)
      end

      def assign_attributes(attrs)
      end

      def save
        true
      end
    end.new(address)
  end

  def a_deep_order_resource
    Class.new do
      def line_items = []

      def line_items_attributes=(attrs)
      end

      def assign_attributes(attrs)
        attrs.each { |k, v| public_send(:"#{k}=", v) }
      end

      def save = true
    end.new
  end

  def a_line_item(name:, quantity:)
    Struct.new(:name, :quantity).new(name, quantity)
  end

  def an_address(street:)
    Struct.new(:street).new(street)
  end
end
