# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Orders (Halitosis errors)", type: :request do
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
    context "with invalid parent params" do
      before { post "/api/orders", params: {order: valid_params[:order].merge(customer_name: "")} }

      it "returns 422" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns a JSON:API errors array" do
        expect(response.parsed_body["errors"]).to be_an(Array)
      end

      it "includes a code derived from the attribute and error type" do
        error = response.parsed_body["errors"].find { |e| e.dig("source", "pointer") == "/order/customer_name" }
        expect(error).to eq(
          "code" => "customer_name_blank",
          "detail" => "Customer name can't be blank",
          "source" => {"pointer" => "/order/customer_name"}
        )
      end
    end

    context "with invalid nested line item params" do
      before do
        post "/api/orders", params: {order: valid_params[:order].merge(line_items: [{name: "", quantity: 0}])}
      end

      it "returns 422" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "includes an error for the name field with an indexed pointer" do
        error = response.parsed_body["errors"].find { |e| e.dig("source", "pointer") == "/order/line_items/0/name" }
        expect(error).to eq(
          "code" => "line_items_0_name_blank",
          "detail" => "Line items[0] name can't be blank",
          "source" => {"pointer" => "/order/line_items/0/name"}
        )
      end

      it "includes an error for the quantity field with an indexed pointer" do
        error = response.parsed_body["errors"].find { |e| e.dig("source", "pointer") == "/order/line_items/0/quantity" }
        expect(error).to eq(
          "code" => "line_items_0_quantity_greater_than",
          "detail" => "Line items[0] quantity must be greater than 0",
          "source" => {"pointer" => "/order/line_items/0/quantity"}
        )
      end

      it "includes a code for propagated nested errors" do
        errors = response.parsed_body["errors"].select { |e|
          e.dig("source", "pointer")&.start_with?("/order/line_items")
        }
        expect(errors).to all(include("code"))
      end
    end

    context "with invalid billing address params" do
      before do
        post "/api/orders", params: {order: valid_params[:order].merge(billing_address: {street: "", city: "", postcode: ""})}
      end

      it "returns 422" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "includes an error for each billing address field" do
        expect(response.parsed_body["errors"]).to contain_exactly(
          {"code" => "billing_address_street_blank", "detail" => "Billing address street can't be blank", "source" => {"pointer" => "/order/billing_address/street"}},
          {"code" => "billing_address_city_blank", "detail" => "Billing address city can't be blank", "source" => {"pointer" => "/order/billing_address/city"}},
          {"code" => "billing_address_postcode_blank", "detail" => "Billing address postcode can't be blank", "source" => {"pointer" => "/order/billing_address/postcode"}}
        )
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

    context "with invalid nested line item params" do
      before do
        patch "/api/orders/#{order.id}", params: {
          order: {
            customer_name: "Charlie",
            line_items: [{id: order.line_items.first.id, name: "", quantity: 0}],
            billing_address: {street: "3 Pine Rd", city: "Capital City", postcode: "11111"}
          }
        }
      end

      it "returns 422" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "includes an error for the name field with an indexed pointer" do
        error = response.parsed_body["errors"].find { |e| e.dig("source", "pointer") == "/order/line_items/0/name" }
        expect(error).to eq(
          "code" => "line_items_0_name_blank",
          "detail" => "Line items[0] name can't be blank",
          "source" => {"pointer" => "/order/line_items/0/name"}
        )
      end

      it "includes an error for the quantity field with an indexed pointer" do
        error = response.parsed_body["errors"].find { |e| e.dig("source", "pointer") == "/order/line_items/0/quantity" }
        expect(error).to eq(
          "code" => "line_items_0_quantity_greater_than",
          "detail" => "Line items[0] quantity must be greater than 0",
          "source" => {"pointer" => "/order/line_items/0/quantity"}
        )
      end
    end

    context "with invalid billing address params" do
      before do
        patch "/api/orders/#{order.id}", params: {
          order: {
            customer_name: "Charlie",
            line_items: [{id: order.line_items.first.id, name: "Widget", quantity: 1}],
            billing_address: {street: "", city: "", postcode: ""}
          }
        }
      end

      it "returns 422" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "includes an error for each billing address field" do
        expect(response.parsed_body["errors"]).to contain_exactly(
          {"code" => "billing_address_street_blank", "detail" => "Billing address street can't be blank", "source" => {"pointer" => "/order/billing_address/street"}},
          {"code" => "billing_address_city_blank", "detail" => "Billing address city can't be blank", "source" => {"pointer" => "/order/billing_address/city"}},
          {"code" => "billing_address_postcode_blank", "detail" => "Billing address postcode can't be blank", "source" => {"pointer" => "/order/billing_address/postcode"}}
        )
      end
    end
  end
end
