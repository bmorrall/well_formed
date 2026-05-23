# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Orders (simple_form)", type: :request do
  let(:valid_params) do
    {
      order: {
        customer_name: "Alice",
        line_items_attributes: [{name: "Widget", quantity: 2}],
        billing_address_attributes: {street: "1 Main St", city: "Springfield", postcode: "12345"}
      }
    }
  end

  describe "GET /simple_form/orders/new" do
    it "returns 200" do
      get "/simple_form/orders/new"
      expect(response).to have_http_status(:ok)
    end

    it "renders a form posting to /orders" do
      get "/simple_form/orders/new"
      expect(response.body).to have_selector('form[action="/simple_form/orders"]')
    end

    it "renders the customer_name field" do
      get "/simple_form/orders/new"
      expect(response.body).to have_field("order[customer_name]")
    end

    it "renders a nested line item name field" do
      get "/simple_form/orders/new"
      expect(response.body).to have_field("order[line_items_attributes][0][name]")
    end

    it "renders a nested line item quantity field" do
      get "/simple_form/orders/new"
      expect(response.body).to have_field("order[line_items_attributes][0][quantity]")
    end

    it "renders the billing address street field" do
      get "/simple_form/orders/new"
      expect(response.body).to have_field("order[billing_address_attributes][street]")
    end
  end

  describe "POST /simple_form/orders" do
    context "with valid params" do
      it "creates the order and redirects to show" do
        expect { post "/simple_form/orders", params: valid_params }.to change(Order, :count).by(1)
        expect(response).to redirect_to(order_path(Order.last))
      end

      it "creates the associated line items" do
        post "/simple_form/orders", params: valid_params
        expect(Order.last.line_items.count).to eq(1)
        expect(Order.last.line_items.first.name).to eq("Widget")
      end

      it "creates the billing address" do
        post "/simple_form/orders", params: valid_params
        expect(Order.last.billing_address.street).to eq("1 Main St")
      end
    end

    context "with invalid parent params" do
      it "returns 422" do
        post "/simple_form/orders", params: {order: valid_params[:order].merge(customer_name: "")}
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "shows an inline error on the customer_name field" do
        post "/simple_form/orders", params: {order: valid_params[:order].merge(customer_name: "")}
        expect(response.body).to have_css(".order_customer_name span.error", text: "Customer name can't be blank")
      end

      it "re-renders the form" do
        post "/simple_form/orders", params: {order: valid_params[:order].merge(customer_name: "")}
        expect(response.body).to have_selector('form[action="/simple_form/orders"]')
      end
    end

    context "with invalid nested line item params" do
      let(:bad_line_items) { {order: valid_params[:order].merge(line_items_attributes: [{name: "", quantity: 0}])} }

      it "returns 422" do
        post "/simple_form/orders", params: bad_line_items
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "shows an inline error on the line item name field" do
        post "/simple_form/orders", params: bad_line_items
        expect(response.body).to have_css(".order_line_items_name span.error", text: "Name can't be blank")
      end

      it "shows an inline error on the line item quantity field" do
        post "/simple_form/orders", params: bad_line_items
        expect(response.body).to have_css(".order_line_items_quantity span.error", text: "Quantity must be greater than 0")
      end
    end

    context "with invalid billing address params" do
      let(:bad_billing) { {order: valid_params[:order].merge(billing_address_attributes: {street: "", city: "", postcode: ""})} }

      it "returns 422" do
        post "/simple_form/orders", params: bad_billing
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "shows inline errors on the billing address fields" do
        post "/simple_form/orders", params: bad_billing
        expect(response.body).to have_css(".order_billing_address_street span.error", text: "Street can't be blank")
        expect(response.body).to have_css(".order_billing_address_city span.error", text: "City can't be blank")
        expect(response.body).to have_css(".order_billing_address_postcode span.error", text: "Postcode can't be blank")
      end
    end
  end

  describe "GET /simple_form/orders/:id/edit" do
    let!(:order) do
      o = Order.create!(customer_name: "Bob")
      o.line_items.create!(name: "Gizmo", quantity: 1)
      o.create_billing_address!(street: "2 Oak Ave", city: "Shelbyville", postcode: "67890")
      o
    end

    it "returns 200" do
      get "/simple_form/orders/#{order.id}/edit"
      expect(response).to have_http_status(:ok)
    end

    it "renders a form patching /orders/:id" do
      get "/simple_form/orders/#{order.id}/edit"
      expect(response.body).to have_selector("form[action='/simple_form/orders/#{order.id}']")
    end

    it "uses PATCH method" do
      get "/simple_form/orders/#{order.id}/edit"
      expect(response.body).to have_selector('input[name="_method"][value="patch"]', visible: :all)
    end

    it "pre-populates the customer_name field" do
      get "/simple_form/orders/#{order.id}/edit"
      expect(response.body).to have_field("order[customer_name]", with: "Bob")
    end
  end

  describe "PATCH /simple_form/orders/:id" do
    let!(:order) do
      o = Order.create!(customer_name: "Bob")
      o.line_items.create!(name: "Gizmo", quantity: 1)
      o.create_billing_address!(street: "2 Oak Ave", city: "Shelbyville", postcode: "67890")
      o
    end

    context "with valid params" do
      it "updates the order and redirects to show" do
        patch "/simple_form/orders/#{order.id}", params: {
          order: {
            customer_name: "Charlie",
            line_items_attributes: [{id: order.line_items.first.id, name: "Updated", quantity: 5}],
            billing_address_attributes: {street: "3 Pine Rd", city: "Capital City", postcode: "11111"}
          }
        }
        expect(response).to redirect_to(order_path(order))
        expect(order.reload.customer_name).to eq("Charlie")
      end
    end

    context "with invalid nested line item params" do
      it "returns 422 and shows inline errors" do
        patch "/simple_form/orders/#{order.id}", params: {
          order: {
            customer_name: "Charlie",
            line_items_attributes: [{id: order.line_items.first.id, name: "", quantity: 0}],
            billing_address_attributes: {street: "3 Pine Rd", city: "Capital City", postcode: "11111"}
          }
        }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to have_css(".order_line_items_name span.error")
      end
    end

    context "with invalid billing address params" do
      it "returns 422 and shows inline errors on billing address fields" do
        patch "/simple_form/orders/#{order.id}", params: {
          order: {
            customer_name: "Charlie",
            line_items_attributes: [{id: order.line_items.first.id, name: "Widget", quantity: 1}],
            billing_address_attributes: {street: "", city: "", postcode: ""}
          }
        }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to have_css(".order_billing_address_street span.error")
        expect(response.body).to have_css(".order_billing_address_city span.error")
        expect(response.body).to have_css(".order_billing_address_postcode span.error")
      end
    end
  end
end
