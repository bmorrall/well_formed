# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Orders (simple_form)", type: :request do
  describe "GET /simple_form/orders/new", :aggregate_failures do
    it "renders a form for a new order with nested fields" do
      get new_simple_form_order_path

      expect(response).to have_http_status(:ok)

      expect(response.body).to have_css("form[action='#{simple_form_orders_path}']")
      expect(response.body).not_to have_patch_method_input
      expect(response.body).to have_field("order[customer_name]")
      expect(response.body).to have_field("order[line_items_attributes][0][name]")
      expect(response.body).to have_field("order[line_items_attributes][0][quantity]")
      expect(response.body).to have_field("order[billing_address_attributes][street]")
    end
  end

  describe "POST /simple_form/orders", :aggregate_failures do
    it "creates an order with its line items and billing address" do
      expect {
        post simple_form_orders_path, params: {
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

    it "re-renders the form with an error when the customer name is blank" do
      expect {
        post simple_form_orders_path, params: {order: a_valid_order_hash(customer_name: "")}
      }.not_to change(Order, :count)

      expect(response).to have_http_status(:unprocessable_content)

      expect(response.body).to have_css("form[action='#{simple_form_orders_path}']")
      expect(response.body).to have_css(".order_customer_name span.error", text: "Customer name can't be blank")
    end

    it "re-renders the form with errors when a line item is invalid" do
      expect {
        post simple_form_orders_path, params: {order: a_valid_order_hash(line_items_attributes: [{name: "", quantity: 0}])}
      }.not_to change(Order, :count)

      expect(response).to have_http_status(:unprocessable_content)

      expect(response.body).to have_css(".order_line_items_name span.error", text: "Name can't be blank")
      expect(response.body).to have_css(".order_line_items_quantity span.error", text: "Quantity must be greater than 0")
    end

    it "re-renders the form with errors when the billing address is invalid" do
      expect {
        post simple_form_orders_path, params: {
          order: a_valid_order_hash(billing_address_attributes: {street: "", city: "", postcode: ""})
        }
      }.not_to change(Order, :count)

      expect(response).to have_http_status(:unprocessable_content)

      expect(response.body).to have_css(".order_billing_address_street span.error", text: "Street can't be blank")
      expect(response.body).to have_css(".order_billing_address_city span.error", text: "City can't be blank")
      expect(response.body).to have_css(".order_billing_address_postcode span.error", text: "Postcode can't be blank")
    end
  end

  describe "GET /simple_form/orders/:id/edit", :aggregate_failures do
    it "renders a form patching the existing order" do
      order = create_order(customer_name: "Bob")

      get edit_simple_form_order_path(order)

      expect(response).to have_http_status(:ok)

      expect(response.body).to have_css("form[action='#{simple_form_order_path(order)}']")
      expect(response.body).to have_patch_method_input
      expect(response.body).to have_field("order[customer_name]", with: "Bob")
    end
  end

  describe "PATCH /simple_form/orders/:id", :aggregate_failures do
    it "updates the order with its line items and billing address" do
      order = create_order
      line_item = order.line_items.sole

      expect {
        patch simple_form_order_path(order), params: {
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
        patch simple_form_order_path(order), params: {
          order: a_valid_order_hash(
            customer_name: "Charlie",
            line_items_attributes: [{id: line_item.id, name: "", quantity: 0}]
          )
        }
      }.not_to change { order.reload.customer_name }

      expect(response).to have_http_status(:unprocessable_content)

      expect(response.body).to have_css(".order_line_items_name span.error")
    end

    it "re-renders the form with errors when the billing address is invalid" do
      order = create_order
      line_item = order.line_items.sole

      expect {
        patch simple_form_order_path(order), params: {
          order: a_valid_order_hash(
            customer_name: "Charlie",
            line_items_attributes: [{id: line_item.id, name: "Widget", quantity: 1}],
            billing_address_attributes: {street: "", city: "", postcode: ""}
          )
        }
      }.not_to change { order.reload.customer_name }

      expect(response).to have_http_status(:unprocessable_content)

      expect(response.body).to have_css(".order_billing_address_street span.error")
      expect(response.body).to have_css(".order_billing_address_city span.error")
      expect(response.body).to have_css(".order_billing_address_postcode span.error")
    end
  end

  def a_valid_order_hash(**attributes)
    {
      customer_name: "Alice",
      line_items_attributes: [{name: "Widget", quantity: 2}],
      billing_address_attributes: {street: "1 Main St", city: "Springfield", postcode: "12345"}
    }.merge(attributes)
  end

  def create_order(customer_name: "Bob")
    order = Order.create!(customer_name:)
    order.line_items.create!(name: "Gizmo", quantity: 1)
    order.create_billing_address!(street: "2 Oak Ave", city: "Shelbyville", postcode: "67890")
    order
  end
end
