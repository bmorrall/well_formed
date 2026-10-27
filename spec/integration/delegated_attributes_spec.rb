# frozen_string_literal: true

require "rails_helper"

RSpec.describe "delegated_attribute_for (integration)", type: :integration do
  describe "attribute_names" do
    it "includes billing_address_attributes but not the individual delegated attrs" do
      attribute_names = an_order_form_class.attribute_names

      expect(attribute_names).to include("customer_name", "billing_address_attributes")
      expect(attribute_names).not_to include("street", "city", "postcode")
    end
  end

  describe "individual virtual accessors" do
    context "when the value was assigned via flat params" do
      it "returns the value from the billing_address_attributes hash" do
        form = an_order_form_class.new(Order.new, nil, {street: "1 Main St", city: "Springfield", postcode: "12345"})

        expect(form.street).to eq("1 Main St")
        expect(form.city).to eq("Springfield")
        expect(form.postcode).to eq("12345")
      end

      it "stores the values under billing_address_attributes in attributes" do
        form = an_order_form_class.new(Order.new, nil, {street: "1 Main St", city: "Springfield", postcode: "12345"})

        expect(form.attributes["billing_address_attributes"]).to eq(
          "street" => "1 Main St",
          "city" => "Springfield",
          "postcode" => "12345"
        )
      end

      it "does not include flat attrs as top-level keys in attributes" do
        form = an_order_form_class.new(Order.new, nil, a_flat_params_hash)

        expect(form.attributes).not_to have_key("street")
        expect(form.attributes).not_to have_key("city")
        expect(form.attributes).not_to have_key("postcode")
      end
    end

    context "when the value was NOT provided in params" do
      it "delegates to resource.billing_address.<attr>" do
        order = Order.create!(customer_name: "Bob")
        order.create_billing_address!(street: "99 Oak Ave", city: "Shelbyville", postcode: "99999")

        form = an_order_form_class.new(order, nil)

        expect(form.street).to eq("99 Oak Ave")
        expect(form.city).to eq("Shelbyville")
        expect(form.postcode).to eq("99999")
      end

      it "returns nil when the resource has no billing_address" do
        form = an_order_form_class.new(Order.new, nil)

        expect(form.street).to be_nil
        expect(form.city).to be_nil
        expect(form.postcode).to be_nil
      end
    end

    it "returns the param value for assigned attrs and delegates to the resource for unassigned ones" do
      order = Order.create!(customer_name: "Bob")
      order.create_billing_address!(street: "99 Oak Ave", city: "Shelbyville", postcode: "99999")

      form = an_order_form_class.new(order, nil, {street: "New Street"})

      expect(form.street).to eq("New Street")
      expect(form.city).to eq("Shelbyville")
      expect(form.postcode).to eq("99999")
    end

    it "updates billing_address_attributes in attributes when assigned directly via street=" do
      form = an_order_form_class.new(Order.new, nil, {customer_name: "Alice"})

      form.street = "Direct St"

      expect(form.street).to eq("Direct St")
      expect(form.attributes["billing_address_attributes"]["street"]).to eq("Direct St")
    end
  end

  describe "assign_attributes_to" do
    it "calls billing_address_attributes= on the resource with delegated values" do
      order = Order.new
      allow(order).to receive(:billing_address_attributes=).and_call_original
      form = an_order_form_class.new(order, nil, {customer_name: "Alice", street: "1 Main St", city: "Springfield", postcode: "12345"})

      form.save

      expect(order).to have_received(:billing_address_attributes=)
        .with(hash_including("street" => "1 Main St", "city" => "Springfield", "postcode" => "12345"))
    end

    it "assigns non-delegated attributes directly" do
      order = Order.new
      form = an_order_form_class.new(order, nil, a_flat_params_hash(customer_name: "Alice"))

      form.save

      expect(order.customer_name).to eq("Alice")
    end
  end

  describe "validations" do
    it "is invalid when a delegated attr is blank" do
      form = an_order_form_class.new(Order.new, nil, {customer_name: "Alice"})

      expect(form).not_to be_valid
      expect(form.errors[:street]).to include("can't be blank")
      expect(form.errors[:city]).to include("can't be blank")
      expect(form.errors[:postcode]).to include("can't be blank")
    end

    it "is valid when all delegated attrs are present" do
      form = an_order_form_class.new(Order.new, nil, a_flat_params_hash)

      expect(form).to be_valid
    end
  end

  describe "save" do
    it "creates an order and billing address with correct values (flat params)" do
      order = Order.new
      form = an_order_form_class.new(order, nil, {customer_name: "Alice", street: "1 Main St", city: "Springfield", postcode: "12345"})

      expect { form.save }.to change(Order, :count).by(1).and change(BillingAddress, :count).by(1)
      expect(order.customer_name).to eq("Alice")
      expect(order.billing_address).to have_attributes(street: "1 Main St", city: "Springfield", postcode: "12345")
    end

    it "delegates unassigned attrs from the resource association on update" do
      order = Order.create!(customer_name: "Original")
      order.create_billing_address!(street: "Old St", city: "Old City", postcode: "00000")
      # Only customer_name is in params — billing address attrs are not submitted
      form = an_order_form_class.new(order, nil, {customer_name: "Updated"})

      expect { form.save }.not_to change { order.reload.billing_address.street }.from("Old St")
      expect(order.customer_name).to eq("Updated")
    end
  end

  def an_order_form_class
    Class.new(WellFormed::ResourceForm) do
      resource_alias :order

      attribute :customer_name, :string

      validates :customer_name, presence: true

      delegated_attribute_for :billing_address do
        attribute :street, :string
        attribute :city, :string
        attribute :postcode, :string

        validates :street, presence: true
        validates :city, presence: true
        validates :postcode, presence: true
      end

      private

      def perform
        assign_attributes_to(resource)
        resource.save
      end
    end
  end

  def a_flat_params_hash(customer_name: "Alice")
    {customer_name:, street: "1 Main St", city: "Springfield", postcode: "12345"}
  end
end
