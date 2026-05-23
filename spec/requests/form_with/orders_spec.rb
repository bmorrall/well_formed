# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Orders (form_with)", type: :request do
  let(:valid_params) do
    {
      order: {
        customer_name: "Alice",
        line_items_attributes: [{name: "Widget", quantity: 2}],
        billing_address_attributes: {street: "1 Main St", city: "Springfield", postcode: "12345"}
      }
    }
  end

  describe "GET /form_with/orders/new" do
    it "returns 200" do
      get "/orders/new"
      expect(response).to have_http_status(:ok)
    end

    it "renders a form posting to /form_with/orders" do
      get "/orders/new"
      expect(response.body).to have_selector('form[action="/orders"]')
    end

    it "renders the customer_name field" do
      get "/orders/new"
      expect(response.body).to have_field("order[customer_name]")
    end

    it "renders a nested line item name field with the correct index" do
      get "/orders/new"
      expect(response.body).to have_field("order[line_items_attributes][0][name]")
    end

    it "renders a nested line item quantity field with the correct index" do
      get "/orders/new"
      expect(response.body).to have_field("order[line_items_attributes][0][quantity]")
    end

    it "renders the billing address street field" do
      get "/orders/new"
      expect(response.body).to have_field("order[billing_address_attributes][street]")
    end
  end

  describe "POST /form_with/orders" do
    context "with valid params" do
      it "creates the order and redirects to show" do
        expect { post "/orders", params: valid_params }.to change(Order, :count).by(1)
        expect(response).to redirect_to(order_path(Order.last))
      end

      it "creates the associated line items" do
        post "/orders", params: valid_params
        expect(Order.last.line_items.count).to eq(1)
        expect(Order.last.line_items.first.name).to eq("Widget")
      end

      it "creates the billing address" do
        post "/orders", params: valid_params
        expect(Order.last.billing_address.street).to eq("1 Main St")
      end
    end

    context "with invalid parent params" do
      it "returns 422" do
        post "/orders", params: {order: valid_params[:order].merge(customer_name: "")}
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "re-renders the form" do
        post "/orders", params: {order: valid_params[:order].merge(customer_name: "")}
        expect(response.body).to have_selector('form[action="/orders"]')
      end

      it "shows an inline error on the customer_name field" do
        post "/orders", params: {order: valid_params[:order].merge(customer_name: "")}
        expect(response.body).to have_css("span.customer-name-error", text: "can't be blank")
      end
    end

    context "with invalid nested line item params" do
      let(:bad_params) { {order: valid_params[:order].merge(line_items_attributes: [{name: "", quantity: 0}])} }

      it "returns 422" do
        post "/orders", params: bad_params
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "shows an inline error on the line item name field" do
        post "/orders", params: bad_params
        expect(response.body).to have_css("span.line-item-name-error", text: "can't be blank")
      end

      it "shows an inline error on the line item quantity field" do
        post "/orders", params: bad_params
        expect(response.body).to have_css("span.line-item-quantity-error", text: "must be greater than 0")
      end
    end

    context "with line_items_attributes as a hash with string integer keys (HTML form encoding)" do
      let(:form_encoded_params) do
        {order: valid_params[:order].merge(line_items_attributes: {"0" => {name: "Widget", quantity: 2}})}
      end

      it "creates the order and redirects to show" do
        expect { post "/orders", params: form_encoded_params }.to change(Order, :count).by(1)
        expect(response).to redirect_to(order_path(Order.last))
      end

      it "creates the associated line items" do
        post "/orders", params: form_encoded_params
        expect(Order.last.line_items.count).to eq(1)
        expect(Order.last.line_items.first.name).to eq("Widget")
      end

      it "returns 422 and shows errors when a line item is invalid" do
        invalid = {order: valid_params[:order].merge(line_items_attributes: {"0" => {name: "", quantity: 0}})}
        post "/orders", params: invalid
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to have_css("span.line-item-name-error", text: "can't be blank")
      end
    end

    context "with invalid billing address params" do
      let(:bad_params) { {order: valid_params[:order].merge(billing_address_attributes: {street: "", city: "", postcode: ""})} }

      it "returns 422" do
        post "/orders", params: bad_params
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "shows an inline error on the billing street field" do
        post "/orders", params: bad_params
        expect(response.body).to have_css("span.billing-street-error", text: "can't be blank")
      end
    end
  end

  describe "GET /form_with/orders/:id/edit" do
    let!(:order) do
      o = Order.create!(customer_name: "Bob")
      o.line_items.create!(name: "Gizmo", quantity: 1)
      o.create_billing_address!(street: "2 Oak Ave", city: "Shelbyville", postcode: "67890")
      o
    end

    it "returns 200" do
      get "/orders/#{order.id}/edit"
      expect(response).to have_http_status(:ok)
    end

    it "pre-populates the customer_name field" do
      get "/orders/#{order.id}/edit"
      expect(response.body).to have_field("order[customer_name]", with: "Bob")
    end

    it "renders the existing line item name field with the correct index" do
      get "/orders/#{order.id}/edit"
      expect(response.body).to have_field("order[line_items_attributes][0][name]", with: "Gizmo")
    end
  end

  describe "PATCH /form_with/orders/:id" do
    let!(:order) do
      o = Order.create!(customer_name: "Bob")
      o.line_items.create!(name: "Gizmo", quantity: 1)
      o.create_billing_address!(street: "2 Oak Ave", city: "Shelbyville", postcode: "67890")
      o
    end

    context "with valid params" do
      it "updates the order and redirects to show" do
        patch "/orders/#{order.id}", params: {
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
        patch "/orders/#{order.id}", params: {
          order: {
            customer_name: "Charlie",
            line_items_attributes: [{id: order.line_items.first.id, name: "", quantity: 0}],
            billing_address_attributes: {street: "3 Pine Rd", city: "Capital City", postcode: "11111"}
          }
        }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to have_css("span.line-item-name-error")
      end
    end
  end
end
