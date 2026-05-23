# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Orders", type: :request do
  let!(:user) { User.first || User.create!(name: "Test User", email: "test@example.com") }

  let(:valid_params) do
    {
      order: {
        customer_name: "Alice",
        line_items: [{name: "Widget", quantity: 2}],
        billing_address: {street: "1 Main St", city: "Springfield", postcode: "12345"}
      }
    }
  end

  describe "POST /api/orders" do
    context "with valid params (no _attributes suffix)" do
      it "creates the order and returns 201" do
        expect { post "/api/orders", params: valid_params }.to change(Order, :count).by(1)
        expect(response).to have_http_status(:created)
      end

      it "creates the associated line items" do
        post "/api/orders", params: valid_params
        expect(Order.last.line_items.count).to eq(1)
        expect(Order.last.line_items.first.name).to eq("Widget")
      end

      it "creates the billing address" do
        post "/api/orders", params: valid_params
        expect(Order.last.billing_address.street).to eq("1 Main St")
      end
    end

    context "with invalid nested line item params" do
      let(:bad_params) do
        {order: valid_params[:order].merge(line_items: [{name: "", quantity: 0}])}
      end

      it "returns 422" do
        post "/api/orders", params: bad_params
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns errors keyed with JSON Pointer index notation" do
        post "/api/orders", params: bad_params
        pointers = response.parsed_body["errors"].filter_map { |e| e.dig("source", "pointer") }
        expect(pointers).to include("/order/line_items/0/name", "/order/line_items/0/quantity")
      end

      it "does not create the order" do
        expect { post "/api/orders", params: bad_params }.not_to change(Order, :count)
      end
    end

    context "with invalid billing address params" do
      let(:bad_params) do
        {order: valid_params[:order].merge(billing_address: {street: "", city: "", postcode: ""})}
      end

      it "returns 422" do
        post "/api/orders", params: bad_params
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns errors keyed with JSON Pointer slash notation" do
        post "/api/orders", params: bad_params
        pointers = response.parsed_body["errors"].filter_map { |e| e.dig("source", "pointer") }
        expect(pointers).to include("/order/billing_address/street", "/order/billing_address/city", "/order/billing_address/postcode")
      end
    end

    context "with invalid parent params" do
      it "returns 422 with customer_name error" do
        post "/api/orders", params: {order: valid_params[:order].merge(customer_name: "")}
        expect(response).to have_http_status(:unprocessable_content)
        pointers = response.parsed_body["errors"].filter_map { |e| e.dig("source", "pointer") }
        expect(pointers).to include("/order/customer_name")
      end
    end
  end

  describe "PATCH /api/orders/:id" do
    let!(:order) do
      o = Order.create!(customer_name: "Bob")
      o.line_items.create!(name: "Gizmo", quantity: 1)
      o.create_billing_address!(street: "2 Oak Ave", city: "Shelbyville", postcode: "67890")
      o
    end

    context "with valid params (no _attributes suffix)" do
      it "updates the order and returns 200" do
        patch "/api/orders/#{order.id}", params: {
          order: {
            customer_name: "Charlie",
            line_items: [{id: order.line_items.first.id, name: "Updated", quantity: 5}],
            billing_address: {street: "3 Pine Rd", city: "Capital City", postcode: "11111"}
          }
        }
        expect(response).to have_http_status(:ok)
        expect(order.reload.customer_name).to eq("Charlie")
      end
    end

    context "with invalid nested line item params" do
      it "returns 422 with indexed error keys" do
        patch "/api/orders/#{order.id}", params: {
          order: {
            customer_name: "Charlie",
            line_items: [{id: order.line_items.first.id, name: "", quantity: 0}],
            billing_address: {street: "3 Pine Rd", city: "Capital City", postcode: "11111"}
          }
        }
        expect(response).to have_http_status(:unprocessable_content)
        pointers = response.parsed_body["errors"].filter_map { |e| e.dig("source", "pointer") }
        expect(pointers).to include("/order/line_items/0/name")
      end
    end

    context "with invalid billing address params" do
      it "returns 422 with JSON Pointer error keys" do
        patch "/api/orders/#{order.id}", params: {
          order: {
            customer_name: "Charlie",
            line_items: [{id: order.line_items.first.id, name: "Widget", quantity: 1}],
            billing_address: {street: "", city: "", postcode: ""}
          }
        }
        expect(response).to have_http_status(:unprocessable_content)
        pointers = response.parsed_body["errors"].filter_map { |e| e.dig("source", "pointer") }
        expect(pointers).to include("/order/billing_address/street")
      end
    end
  end
end
