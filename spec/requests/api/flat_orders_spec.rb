# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::FlatOrders", type: :request do
  describe "POST /api/flat_orders" do
    context "with valid flat params" do
      let(:valid_params) do
        {order: {customer_name: "Alice", street: "1 Main St", city: "Springfield", postcode: "12345"}}
      end
      it "returns 201" do
        post "/api/flat_orders", params: valid_params

        expect(response).to have_http_status(:created)
      end

      it "creates an order and billing address" do
        expect {
          post "/api/flat_orders", params: valid_params
        }.to change(Order, :count).by(1).and change(BillingAddress, :count).by(1)
      end

      it "returns the order with billing address fields" do
        post "/api/flat_orders", params: valid_params

        json = response.parsed_body
        expect(json["customer_name"]).to eq("Alice")
        expect(json["street"]).to eq("1 Main St")
        expect(json["city"]).to eq("Springfield")
        expect(json["postcode"]).to eq("12345")
      end

      it "persists the billing address on the order" do
        post "/api/flat_orders", params: valid_params

        order = Order.last!
        expect(order.billing_address.street).to eq("1 Main St")
        expect(order.billing_address.city).to eq("Springfield")
        expect(order.billing_address.postcode).to eq("12345")
      end
    end

    context "with missing delegated attributes" do
      it "returns 422 with validation errors" do
        post "/api/flat_orders", params: {order: {customer_name: "Alice"}}

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json["errors"]["street"]).to include("can't be blank")
        expect(json["errors"]["city"]).to include("can't be blank")
        expect(json["errors"]["postcode"]).to include("can't be blank")
      end
    end

    context "with a missing customer_name" do
      it "returns 422 with a customer_name error" do
        post "/api/flat_orders",
          params: {order: {street: "1 Main St", city: "Springfield", postcode: "12345"}}

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json["errors"]["customer_name"]).to include("can't be blank")
      end
    end
  end

  describe "PATCH /api/flat_orders/:id" do
    let(:order) { Order.create!(customer_name: "Original") }
    let(:update_params) do
      {order: {customer_name: "Updated", street: "99 New St", city: "Shelbyville", postcode: "99999"}}
    end

    context "when the order has no billing address" do
      it "returns 200" do
        patch "/api/flat_orders/#{order.id}", params: update_params

        expect(response).to have_http_status(:ok)
      end

      it "creates a new billing address record" do
        expect {
          patch "/api/flat_orders/#{order.id}", params: update_params
        }.to change(BillingAddress, :count).by(1)
      end

      it "associates the new billing address with the order" do
        patch "/api/flat_orders/#{order.id}", params: update_params

        order.reload
        expect(order.billing_address.street).to eq("99 New St")
        expect(order.billing_address.city).to eq("Shelbyville")
        expect(order.billing_address.postcode).to eq("99999")
      end
    end

    context "when the order already has a billing address" do
      before { order.create_billing_address!(street: "Old St", city: "Old City", postcode: "00000") }

      it "returns 200" do
        patch "/api/flat_orders/#{order.id}", params: update_params

        expect(response).to have_http_status(:ok)
      end

      it "does not create an extra billing address record" do
        expect {
          patch "/api/flat_orders/#{order.id}", params: update_params
        }.not_to change(BillingAddress, :count)
      end

      it "updates the existing billing address" do
        patch "/api/flat_orders/#{order.id}", params: update_params

        order.reload
        expect(order.billing_address.street).to eq("99 New St")
        expect(order.billing_address.city).to eq("Shelbyville")
        expect(order.billing_address.postcode).to eq("99999")
      end

      it "returns the updated billing address fields" do
        patch "/api/flat_orders/#{order.id}", params: update_params

        json = response.parsed_body
        expect(json["customer_name"]).to eq("Updated")
        expect(json["street"]).to eq("99 New St")
      end
    end

    context "when params are invalid" do
      it "returns 422 and does not update" do
        patch "/api/flat_orders/#{order.id}", params: {order: {customer_name: ""}}

        expect(response).to have_http_status(:unprocessable_content)
        expect(order.reload.customer_name).to eq("Original")
      end
    end
  end
end
