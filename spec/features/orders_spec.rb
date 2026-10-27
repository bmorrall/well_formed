# frozen_string_literal: true

require "rails_helper"

RSpec.feature "Orders" do
  scenario "Customer places an order and then changes it" do
    # GIVEN I am on the new order page
    visit new_order_path

    # THEN I see the order form
    expect(page).to have_css("form[action='#{orders_path}']")

    # WHEN I fill in my order details
    fill_in "order[customer_name]", with: "Alice"
    fill_in "order[line_items_attributes][0][name]", with: "Widget"
    fill_in "order[line_items_attributes][0][quantity]", with: "2"
    fill_in "order[billing_address_attributes][street]", with: "1 Main St"
    fill_in "order[billing_address_attributes][city]", with: "Springfield"
    fill_in "order[billing_address_attributes][postcode]", with: "12345"

    # AND I place the order
    click_button "Create Order"

    # THEN I see my order
    expect(page).to have_current_path(%r{\A/orders/\d+\z})
    expect(page).to have_css("p", text: "Customer name: Alice")
    expect(page).to have_css("p", text: "Widget × 2")
    expect(page).to have_css("p", text: "1 Main St, Springfield, 12345")

    # WHEN I choose to edit my order
    click_link "Edit"

    # THEN I see the edit order form
    expect(page).to have_current_path(%r{\A/orders/\d+/edit\z})

    # WHEN I change my name and the line item
    fill_in "order[customer_name]", with: "Bob"
    fill_in "order[line_items_attributes][0][name]", with: "Gadget"

    # AND I update the order
    click_button "Update Order"

    # THEN I see my updated order
    expect(page).to have_current_path(%r{\A/orders/\d+\z})
    expect(page).to have_css("p", text: "Customer name: Bob")
    expect(page).to have_css("p", text: "Gadget × 2")
  end

  scenario "Customer sees what to fix when placing an incomplete order" do
    # GIVEN I am on the new order page
    visit new_order_path

    # WHEN I leave my order details blank
    fill_in "order[customer_name]", with: ""
    fill_in "order[line_items_attributes][0][name]", with: ""
    fill_in "order[line_items_attributes][0][quantity]", with: "0"
    fill_in "order[billing_address_attributes][street]", with: ""
    fill_in "order[billing_address_attributes][city]", with: ""
    fill_in "order[billing_address_attributes][postcode]", with: ""

    # AND I place the order
    click_button "Create Order"

    # THEN I stay on the order form
    expect(page).to have_current_path(orders_path)

    # AND I see what to fix
    expect(page).to have_css("span.customer-name-error", text: "can't be blank")
    expect(page).to have_css("span.line-item-name-error", text: "can't be blank")
    expect(page).to have_css("span.line-item-quantity-error", text: "must be greater than 0")
    expect(page).to have_css("span.billing-street-error", text: "can't be blank")
  end

  scenario "Customer sees what to fix when clearing an existing order" do
    # GIVEN I have placed an order
    order = Order.create!(
      customer_name: "Alice",
      line_items_attributes: [{name: "Widget", quantity: 2}],
      billing_address_attributes: {street: "1 Main St", city: "Springfield", postcode: "12345"}
    )

    # AND I am on the page for my order
    visit order_path(order)

    # WHEN I choose to edit my order
    click_link "Edit"

    # AND I clear my order details
    fill_in "order[customer_name]", with: ""
    fill_in "order[line_items_attributes][0][name]", with: ""
    fill_in "order[billing_address_attributes][street]", with: ""

    # AND I update the order
    click_button "Update Order"

    # THEN I stay on the order form
    expect(page).to have_current_path(order_path(order))

    # AND I see what to fix
    expect(page).to have_css("span.error", text: "can't be blank")
    expect(page).to have_css("span.line-item-name-error", text: "can't be blank")
    expect(page).to have_css("span.billing-street-error", text: "can't be blank")
  end
end
