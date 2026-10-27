# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Orders", type: :request do
  describe "POST /api/orders", :aggregate_failures do
    it "creates the order, line items and billing address from params without an _attributes suffix" do
      expect {
        post api_orders_path, params: an_order_params_hash
      }.to change(Order, :count).by(1)

      expect(response).to have_http_status(:created)

      order = Order.last
      expect(order.line_items.count).to eq(1)
      expect(order.line_items.first.name).to eq("Widget")
      expect(order.billing_address.street).to eq("1 Main St")
    end

    it "rejects invalid line items with JSON Pointer index errors" do
      expect {
        post api_orders_path, params: an_order_params_hash(line_items: [{name: "", quantity: 0}])
      }.not_to change(Order, :count)

      expect(response).to have_http_status(:unprocessable_content)

      pointers = response.parsed_body["errors"].filter_map { |e| e.dig("source", "pointer") }
      expect(pointers).to include("/order/line_items/0/name", "/order/line_items/0/quantity")
    end

    it "rejects an invalid billing address with JSON Pointer slash errors" do
      expect {
        post api_orders_path, params: an_order_params_hash(billing_address: {street: "", city: "", postcode: ""})
      }.not_to change(Order, :count)

      expect(response).to have_http_status(:unprocessable_content)

      pointers = response.parsed_body["errors"].filter_map { |e| e.dig("source", "pointer") }
      expect(pointers).to include("/order/billing_address/street", "/order/billing_address/city", "/order/billing_address/postcode")
    end

    it "rejects a blank customer_name" do
      expect {
        post api_orders_path, params: an_order_params_hash(customer_name: "")
      }.not_to change(Order, :count)

      expect(response).to have_http_status(:unprocessable_content)

      pointers = response.parsed_body["errors"].filter_map { |e| e.dig("source", "pointer") }
      expect(pointers).to include("/order/customer_name")
    end
  end

  describe "PATCH /api/orders/:id", :aggregate_failures do
    it "updates the order from params without an _attributes suffix" do
      order = create_order_with_line_item_and_billing_address
      line_item = order.line_items.first

      expect {
        patch api_order_path(order), params: an_order_params_hash(
          customer_name: "Charlie",
          line_items: [{id: line_item.id, name: "Updated", quantity: 5}],
          billing_address: {street: "3 Pine Rd", city: "Capital City", postcode: "11111"}
        )
      }.to change { order.reload.customer_name }.to("Charlie")

      expect(response).to have_http_status(:ok)
    end

    it "rejects invalid line items with JSON Pointer index errors" do
      order = create_order_with_line_item_and_billing_address
      line_item = order.line_items.first

      expect {
        patch api_order_path(order), params: an_order_params_hash(
          customer_name: "Charlie",
          line_items: [{id: line_item.id, name: "", quantity: 0}],
          billing_address: {street: "3 Pine Rd", city: "Capital City", postcode: "11111"}
        )
      }.not_to change { order.reload.customer_name }

      expect(response).to have_http_status(:unprocessable_content)

      pointers = response.parsed_body["errors"].filter_map { |e| e.dig("source", "pointer") }
      expect(pointers).to include("/order/line_items/0/name")
    end

    it "rejects an invalid billing address with JSON Pointer slash errors" do
      order = create_order_with_line_item_and_billing_address
      line_item = order.line_items.first

      expect {
        patch api_order_path(order), params: an_order_params_hash(
          customer_name: "Charlie",
          line_items: [{id: line_item.id, name: "Widget", quantity: 1}],
          billing_address: {street: "", city: "", postcode: ""}
        )
      }.not_to change { order.reload.customer_name }

      expect(response).to have_http_status(:unprocessable_content)

      pointers = response.parsed_body["errors"].filter_map { |e| e.dig("source", "pointer") }
      expect(pointers).to include("/order/billing_address/street")
    end
  end

  def create_order_with_line_item_and_billing_address
    order = Order.create!(customer_name: "Bob")
    order.line_items.create!(name: "Gizmo", quantity: 1)
    order.create_billing_address!(street: "2 Oak Ave", city: "Shelbyville", postcode: "67890")
    order
  end

  def an_order_params_hash(**overrides)
    {
      order: {
        customer_name: "Alice",
        line_items: [{name: "Widget", quantity: 2}],
        billing_address: {street: "1 Main St", city: "Springfield", postcode: "12345"},
        **overrides
      }
    }
  end
end
