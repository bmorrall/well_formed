# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Orders (Halitosis errors)", type: :request do
  describe "POST /api/orders", :aggregate_failures do
    it "returns a JSON:API error with a code for a blank customer name" do
      expect {
        post api_orders_path, params: {order: a_valid_order_hash(customer_name: "")}
      }.not_to change(Order, :count)

      expect(response).to have_http_status(:unprocessable_content)

      expect(response.parsed_body["errors"]).to contain_exactly(
        {"code" => "customer_name_blank", "detail" => "Customer name can't be blank", "source" => {"pointer" => "/order/customer_name"}}
      )
    end

    it "returns JSON:API errors with indexed pointers for an invalid line item" do
      expect {
        post api_orders_path, params: {order: a_valid_order_hash(line_items: [{name: "", quantity: 0}])}
      }.not_to change(Order, :count)

      expect(response).to have_http_status(:unprocessable_content)

      expect(response.parsed_body["errors"]).to contain_exactly(
        {"code" => "line_items_0_name_blank", "detail" => "Line items[0] name can't be blank", "source" => {"pointer" => "/order/line_items/0/name"}},
        {"code" => "line_items_0_quantity_greater_than", "detail" => "Line items[0] quantity must be greater than 0", "source" => {"pointer" => "/order/line_items/0/quantity"}}
      )
    end

    it "returns a JSON:API error for each invalid billing address field" do
      expect {
        post api_orders_path, params: {order: a_valid_order_hash(billing_address: {street: "", city: "", postcode: ""})}
      }.not_to change(Order, :count)

      expect(response).to have_http_status(:unprocessable_content)

      expect(response.parsed_body["errors"]).to contain_exactly(
        {"code" => "billing_address_street_blank", "detail" => "Billing address street can't be blank", "source" => {"pointer" => "/order/billing_address/street"}},
        {"code" => "billing_address_city_blank", "detail" => "Billing address city can't be blank", "source" => {"pointer" => "/order/billing_address/city"}},
        {"code" => "billing_address_postcode_blank", "detail" => "Billing address postcode can't be blank", "source" => {"pointer" => "/order/billing_address/postcode"}}
      )
    end
  end

  describe "PATCH /api/orders/:id", :aggregate_failures do
    it "returns JSON:API errors with indexed pointers for an invalid line item" do
      order = create_order
      line_item = order.line_items.sole

      expect {
        patch api_order_path(order), params: {
          order: a_valid_order_hash(customer_name: "Charlie", line_items: [{id: line_item.id, name: "", quantity: 0}])
        }
      }.not_to change { order.reload.customer_name }

      expect(response).to have_http_status(:unprocessable_content)

      expect(response.parsed_body["errors"]).to contain_exactly(
        {"code" => "line_items_0_name_blank", "detail" => "Line items[0] name can't be blank", "source" => {"pointer" => "/order/line_items/0/name"}},
        {"code" => "line_items_0_quantity_greater_than", "detail" => "Line items[0] quantity must be greater than 0", "source" => {"pointer" => "/order/line_items/0/quantity"}}
      )
    end

    it "returns a JSON:API error for each invalid billing address field" do
      order = create_order
      line_item = order.line_items.sole

      expect {
        patch api_order_path(order), params: {
          order: a_valid_order_hash(
            customer_name: "Charlie",
            line_items: [{id: line_item.id, name: "Widget", quantity: 1}],
            billing_address: {street: "", city: "", postcode: ""}
          )
        }
      }.not_to change { order.reload.customer_name }

      expect(response).to have_http_status(:unprocessable_content)

      expect(response.parsed_body["errors"]).to contain_exactly(
        {"code" => "billing_address_street_blank", "detail" => "Billing address street can't be blank", "source" => {"pointer" => "/order/billing_address/street"}},
        {"code" => "billing_address_city_blank", "detail" => "Billing address city can't be blank", "source" => {"pointer" => "/order/billing_address/city"}},
        {"code" => "billing_address_postcode_blank", "detail" => "Billing address postcode can't be blank", "source" => {"pointer" => "/order/billing_address/postcode"}}
      )
    end
  end

  def a_valid_order_hash(**attributes)
    {
      customer_name: "Alice",
      line_items: [{name: "Widget", quantity: 2}],
      billing_address: {street: "1 Main St", city: "Springfield", postcode: "12345"}
    }.merge(attributes)
  end

  def create_order
    order = Order.create!(customer_name: "Bob")
    order.line_items.create!(name: "Gizmo", quantity: 1)
    order.create_billing_address!(street: "2 Oak Ave", city: "Shelbyville", postcode: "67890")
    order
  end
end
