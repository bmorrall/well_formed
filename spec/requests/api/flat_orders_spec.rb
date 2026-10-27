# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::FlatOrders", type: :request do
  describe "POST /api/flat_orders", :aggregate_failures do
    it "creates the order and its billing address from flat params" do
      expect {
        post api_flat_orders_path, params: {order: {customer_name: "Alice", street: "1 Main St", city: "Springfield", postcode: "12345"}}
      }.to change(Order, :count).by(1)
        .and change(BillingAddress, :count).by(1)

      expect(response).to have_http_status(:created)

      json = response.parsed_body
      expect(json["customer_name"]).to eq("Alice")
      expect(json["street"]).to eq("1 Main St")
      expect(json["city"]).to eq("Springfield")
      expect(json["postcode"]).to eq("12345")

      billing_address = Order.last!.billing_address
      expect(billing_address.street).to eq("1 Main St")
      expect(billing_address.city).to eq("Springfield")
      expect(billing_address.postcode).to eq("12345")
    end

    it "rejects missing delegated attributes" do
      expect {
        post api_flat_orders_path, params: {order: {customer_name: "Alice"}}
      }.not_to change { [Order.count, BillingAddress.count] }

      expect(response).to have_http_status(:unprocessable_content)

      json = response.parsed_body
      expect(json["errors"]["street"]).to include("can't be blank")
      expect(json["errors"]["city"]).to include("can't be blank")
      expect(json["errors"]["postcode"]).to include("can't be blank")
    end

    it "rejects a missing customer_name" do
      expect {
        post api_flat_orders_path, params: {order: {street: "1 Main St", city: "Springfield", postcode: "12345"}}
      }.not_to change { [Order.count, BillingAddress.count] }

      expect(response).to have_http_status(:unprocessable_content)

      json = response.parsed_body
      expect(json["errors"]["customer_name"]).to include("can't be blank")
    end
  end

  describe "PATCH /api/flat_orders/:id", :aggregate_failures do
    it "creates a billing address for an order without one" do
      order = Order.create!(customer_name: "Original")

      expect {
        patch api_flat_order_path(order), params: an_order_update_params_hash
      }.to change(BillingAddress, :count).by(1)
        .and change { order.reload.customer_name }.to("Updated")

      expect(response).to have_http_status(:ok)

      billing_address = order.reload.billing_address
      expect(billing_address.street).to eq("99 New St")
      expect(billing_address.city).to eq("Shelbyville")
      expect(billing_address.postcode).to eq("99999")
    end

    it "updates the existing billing address of an order with one" do
      order = Order.create!(customer_name: "Original")
      order.create_billing_address!(street: "Old St", city: "Old City", postcode: "00000")

      expect {
        patch api_flat_order_path(order), params: an_order_update_params_hash
      }.not_to change(BillingAddress, :count)

      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json["customer_name"]).to eq("Updated")
      expect(json["street"]).to eq("99 New St")

      order.reload
      expect(order.customer_name).to eq("Updated")

      billing_address = order.billing_address
      expect(billing_address.street).to eq("99 New St")
      expect(billing_address.city).to eq("Shelbyville")
      expect(billing_address.postcode).to eq("99999")
    end

    it "rejects a blank customer_name" do
      order = Order.create!(customer_name: "Original")

      expect {
        patch api_flat_order_path(order), params: {order: {customer_name: ""}}
      }.not_to change { order.reload.customer_name }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  def an_order_update_params_hash
    {order: {customer_name: "Updated", street: "99 New St", city: "Shelbyville", postcode: "99999"}}
  end
end
