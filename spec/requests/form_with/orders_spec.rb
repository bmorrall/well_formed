# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Orders (form_with)", type: :request do
  describe "GET /orders/new", :aggregate_failures do
    it "renders a form for a new order with nested fields" do
      get new_order_path

      expect(response).to have_http_status(:ok)

      expect(response.body).to have_css("form[action='#{orders_path}']")
      expect(response.body).to have_field("order[customer_name]")
      expect(response.body).to have_field("order[line_items_attributes][0][name]")
      expect(response.body).to have_field("order[line_items_attributes][0][quantity]")
      expect(response.body).to have_field("order[billing_address_attributes][street]")
    end
  end

  describe "POST /orders", :aggregate_failures do
    it "creates an order with its line items and billing address" do
      expect {
        post orders_path, params: {
          order: {
            customer_name: "Alice",
            line_items_attributes: [{name: "Widget", quantity: 2}],
            billing_address_attributes: {street: "1 Main St", city: "Springfield", postcode: "12345"}
          }
        }
      }.to change(Order, :count).by(1)

      order = Order.last!
      expect(response).to redirect_to(order_path(order))
      expect(order.customer_name).to eq("Alice")
      expect(order.line_items).to contain_exactly(have_attributes(name: "Widget", quantity: 2))
      expect(order.billing_address).to have_attributes(street: "1 Main St", city: "Springfield", postcode: "12345")
    end

    it "creates an order with line items keyed by string indexes (HTML form encoding)" do
      expect {
        post orders_path, params: {
          order: a_valid_order_hash(line_items_attributes: {"0" => {name: "Widget", quantity: 2}})
        }
      }.to change(Order, :count).by(1)

      order = Order.last!
      expect(response).to redirect_to(order_path(order))
      expect(order.line_items).to contain_exactly(have_attributes(name: "Widget", quantity: 2))
    end

    it "re-renders the form with an error when the customer name is blank" do
      expect {
        post orders_path, params: {order: a_valid_order_hash(customer_name: "")}
      }.not_to change(Order, :count)

      expect(response).to have_http_status(:unprocessable_content)

      expect(response.body).to have_css("form[action='#{orders_path}']")
      expect(response.body).to have_css("span.customer-name-error", text: "can't be blank")
    end

    it "re-renders the form with errors when a line item is invalid" do
      expect {
        post orders_path, params: {order: a_valid_order_hash(line_items_attributes: [{name: "", quantity: 0}])}
      }.not_to change(Order, :count)

      expect(response).to have_http_status(:unprocessable_content)

      expect(response.body).to have_css("span.line-item-name-error", text: "can't be blank")
      expect(response.body).to have_css("span.line-item-quantity-error", text: "must be greater than 0")
    end

    it "re-renders the form with an error when a line item keyed by string index is invalid" do
      expect {
        post orders_path, params: {order: a_valid_order_hash(line_items_attributes: {"0" => {name: "", quantity: 0}})}
      }.not_to change(Order, :count)

      expect(response).to have_http_status(:unprocessable_content)

      expect(response.body).to have_css("span.line-item-name-error", text: "can't be blank")
    end

    it "re-renders the form with an error when the billing address is invalid" do
      expect {
        post orders_path, params: {
          order: a_valid_order_hash(billing_address_attributes: {street: "", city: "", postcode: ""})
        }
      }.not_to change(Order, :count)

      expect(response).to have_http_status(:unprocessable_content)

      expect(response.body).to have_css("span.billing-street-error", text: "can't be blank")
    end
  end

  describe "GET /orders/:id/edit", :aggregate_failures do
    it "renders a form for the existing order with nested fields" do
      order = create_order(customer_name: "Bob", line_item_name: "Gizmo")

      get edit_order_path(order)

      expect(response).to have_http_status(:ok)

      expect(response.body).to have_field("order[customer_name]", with: "Bob")
      expect(response.body).to have_field("order[line_items_attributes][0][name]", with: "Gizmo")
    end
  end

  describe "PATCH /orders/:id", :aggregate_failures do
    it "updates the order with its line items and billing address" do
      order = create_order
      line_item = order.line_items.sole

      expect {
        patch order_path(order), params: {
          order: {
            customer_name: "Charlie",
            line_items_attributes: [{id: line_item.id, name: "Updated", quantity: 5}],
            billing_address_attributes: {street: "3 Pine Rd", city: "Capital City", postcode: "11111"}
          }
        }
      }.to change { order.reload.customer_name }.to("Charlie")
        .and change { line_item.reload.name }.to("Updated")

      expect(response).to redirect_to(order_path(order))
      expect(order.billing_address).to have_attributes(street: "3 Pine Rd", city: "Capital City", postcode: "11111")
    end

    it "re-renders the form with errors when a line item is invalid" do
      order = create_order
      line_item = order.line_items.sole

      expect {
        patch order_path(order), params: {
          order: a_valid_order_hash(
            customer_name: "Charlie",
            line_items_attributes: [{id: line_item.id, name: "", quantity: 0}]
          )
        }
      }.not_to change { order.reload.customer_name }

      expect(response).to have_http_status(:unprocessable_content)

      expect(response.body).to have_css("span.line-item-name-error")
    end
  end

  def a_valid_order_hash(**attributes)
    {
      customer_name: "Alice",
      line_items_attributes: [{name: "Widget", quantity: 2}],
      billing_address_attributes: {street: "1 Main St", city: "Springfield", postcode: "12345"}
    }.merge(attributes)
  end

  def create_order(customer_name: "Bob", line_item_name: "Gizmo")
    order = Order.create!(customer_name:)
    order.line_items.create!(name: line_item_name, quantity: 1)
    order.create_billing_address!(street: "2 Oak Ave", city: "Shelbyville", postcode: "67890")
    order
  end
end
