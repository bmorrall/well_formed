# frozen_string_literal: true

require "rails_helper"

RSpec.describe "delegated_attribute_for (integration)", type: :integration do
  let(:form_class) do
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

  let(:valid_flat_params) { {customer_name: "Alice", street: "1 Main St", city: "Springfield", postcode: "12345"} }

  describe "attribute_names" do
    it "includes billing_address_attributes but not the individual delegated attrs" do
      expect(form_class.attribute_names).to include("customer_name", "billing_address_attributes")
      expect(form_class.attribute_names).not_to include("street", "city", "postcode")
    end
  end

  describe "individual virtual accessors" do
    context "when the value was assigned via flat params" do
      it "returns the value from the billing_address_attributes hash" do
        form = form_class.new(Order.new, nil, valid_flat_params)

        expect(form.street).to eq("1 Main St")
        expect(form.city).to eq("Springfield")
        expect(form.postcode).to eq("12345")
      end

      it "stores the values under billing_address_attributes in attributes" do
        form = form_class.new(Order.new, nil, valid_flat_params)

        expect(form.attributes["billing_address_attributes"]).to eq(
          "street" => "1 Main St",
          "city" => "Springfield",
          "postcode" => "12345"
        )
      end

      it "does not include flat attrs as top-level keys in attributes" do
        form = form_class.new(Order.new, nil, valid_flat_params)

        expect(form.attributes).not_to have_key("street")
        expect(form.attributes).not_to have_key("city")
        expect(form.attributes).not_to have_key("postcode")
      end
    end

    context "when the value was NOT provided in params" do
      it "delegates to resource.billing_address.<attr>" do
        order = Order.create!(customer_name: "Bob")
        order.create_billing_address!(street: "99 Oak Ave", city: "Shelbyville", postcode: "99999")

        form = form_class.new(order, nil)

        expect(form.street).to eq("99 Oak Ave")
        expect(form.city).to eq("Shelbyville")
        expect(form.postcode).to eq("99999")
      end

      it "returns nil when the resource has no billing_address" do
        form = form_class.new(Order.new, nil)

        expect(form.street).to be_nil
        expect(form.city).to be_nil
        expect(form.postcode).to be_nil
      end
    end

    context "when only some attributes are in params" do
      it "returns the param value for assigned attrs, delegates to resource for unassigned" do
        order = Order.create!(customer_name: "Bob")
        order.create_billing_address!(street: "99 Oak Ave", city: "Shelbyville", postcode: "99999")

        form = form_class.new(order, nil, {street: "New Street"})

        expect(form.street).to eq("New Street")    # overridden by param
        expect(form.city).to eq("Shelbyville")     # not in params, delegates
        expect(form.postcode).to eq("99999")        # not in params, delegates
      end
    end

    context "direct assignment via street=" do
      it "updates billing_address_attributes in attributes" do
        form = form_class.new(Order.new, nil, {customer_name: "Alice"})
        form.street = "Direct St"

        expect(form.street).to eq("Direct St")
        expect(form.attributes["billing_address_attributes"]["street"]).to eq("Direct St")
      end
    end
  end

  describe "assign_attributes_to" do
    it "calls billing_address_attributes= on the resource with delegated values" do
      order = Order.new
      form = form_class.new(order, nil, valid_flat_params)

      expect(order).to receive(:billing_address_attributes=)
        .with(hash_including("street" => "1 Main St", "city" => "Springfield", "postcode" => "12345"))
        .and_call_original

      form.send(:assign_attributes_to, order)
    end

    it "assigns non-delegated attributes directly" do
      order = Order.new
      form = form_class.new(order, nil, valid_flat_params)
      form.send(:assign_attributes_to, order)

      expect(order.customer_name).to eq("Alice")
    end
  end

  describe "validations" do
    it "is invalid when a delegated attr is blank" do
      form = form_class.new(Order.new, nil, {customer_name: "Alice"})

      expect(form).not_to be_valid
      expect(form.errors[:street]).to include("can't be blank")
      expect(form.errors[:city]).to include("can't be blank")
      expect(form.errors[:postcode]).to include("can't be blank")
    end

    it "is valid when all delegated attrs are present" do
      form = form_class.new(Order.new, nil, valid_flat_params)

      expect(form).to be_valid
    end
  end

  describe "save" do
    it "creates an order and billing address with correct values (flat params)" do
      form = form_class.new(Order.new, nil, valid_flat_params)

      expect { form.save }.to change(Order, :count).by(1).and change(BillingAddress, :count).by(1)

      order = form.resource
      expect(order.customer_name).to eq("Alice")
      expect(order.billing_address.street).to eq("1 Main St")
      expect(order.billing_address.city).to eq("Springfield")
      expect(order.billing_address.postcode).to eq("12345")
    end

    it "delegates unassigned attrs from the resource association on update" do
      order = Order.create!(customer_name: "Original")
      order.create_billing_address!(street: "Old St", city: "Old City", postcode: "00000")

      # Only customer_name is in params — billing address attrs are not submitted
      form = form_class.new(order, nil, {customer_name: "Updated"})
      form.save

      order.reload
      expect(order.customer_name).to eq("Updated")
      expect(order.billing_address.street).to eq("Old St")
    end
  end
end
