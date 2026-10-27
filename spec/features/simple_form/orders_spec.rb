# frozen_string_literal: true

require "rails_helper"

RSpec.feature "SimpleForm Orders" do
  scenario "Customer places an order" do
    # GIVEN I am on the new simple form order page
    visit new_simple_form_order_path

    # THEN I see the simple form order form
    expect(page).to have_css("form[action='#{simple_form_orders_path}']")

    # WHEN I fill in my order details
    fill_in "Customer name", with: "Alice"
    fill_in "Name", with: "Widget"
    fill_in "Quantity", with: "2"
    fill_in "Street", with: "1 Main St"
    fill_in "City", with: "Springfield"
    fill_in "Postcode", with: "12345"

    # AND I place the order
    click_button "Create Order"

    # THEN I see my order
    expect(page).to have_current_path(%r{\A/orders/\d+\z})
    expect(page).to have_css("p", text: "Customer name: Alice")
    expect(page).to have_css("p", text: "Widget × 2")
    expect(page).to have_css("p", text: "1 Main St, Springfield, 12345")
  end

  scenario "Customer changes an existing order" do
    # GIVEN I have placed an order
    order = Order.create!(
      customer_name: "Alice",
      line_items_attributes: [{name: "Widget", quantity: 2}],
      billing_address_attributes: {street: "1 Main St", city: "Springfield", postcode: "12345"}
    )

    # AND I am on the simple form edit page for my order
    visit edit_simple_form_order_path(order)

    # WHEN I change my name and the line item
    fill_in "Customer name", with: "Bob"
    fill_in "Name", with: "Gadget"

    # AND I update the order
    click_button "Update Order"

    # THEN I see my updated order
    expect(page).to have_current_path(order_path(order))
    expect(page).to have_css("p", text: "Customer name: Bob")
    expect(page).to have_css("p", text: "Gadget × 2")
  end

  scenario "Customer sees what to fix when placing an incomplete order" do
    # GIVEN I am on the new simple form order page
    visit new_simple_form_order_path

    # WHEN I leave my order details blank
    fill_in "Customer name", with: ""
    fill_in "Name", with: ""
    fill_in "Quantity", with: "0"
    fill_in "Street", with: ""
    fill_in "City", with: ""
    fill_in "Postcode", with: ""

    # AND I place the order
    click_button "Create Order"

    # THEN I stay on the simple form order form
    expect(page).to have_current_path(simple_form_orders_path)

    # AND I see what to fix
    expect(page).to have_css(".order_customer_name span.error", text: "Customer name can't be blank")
    expect(page).to have_css(".order_line_items_name span.error", text: "Name can't be blank")
    expect(page).to have_css(".order_line_items_quantity span.error", text: "Quantity must be greater than 0")
    expect(page).to have_css(".order_billing_address_street span.error", text: "Street can't be blank")
  end

  scenario "Customer sees what to fix when clearing an existing order" do
    # GIVEN I have placed an order
    order = Order.create!(
      customer_name: "Alice",
      line_items_attributes: [{name: "Widget", quantity: 2}],
      billing_address_attributes: {street: "1 Main St", city: "Springfield", postcode: "12345"}
    )

    # AND I am on the simple form edit page for my order
    visit edit_simple_form_order_path(order)

    # WHEN I clear my order details
    fill_in "Customer name", with: ""
    fill_in "Name", with: ""
    fill_in "Street", with: ""

    # AND I update the order
    click_button "Update Order"

    # THEN I stay on the simple form order form
    expect(page).to have_current_path(simple_form_order_path(order))

    # AND I see what to fix
    expect(page).to have_css(".order_customer_name span.error", text: "Customer name can't be blank")
    expect(page).to have_css(".order_line_items_name span.error", text: "Name can't be blank")
    expect(page).to have_css(".order_billing_address_street span.error", text: "Street can't be blank")
  end
end
