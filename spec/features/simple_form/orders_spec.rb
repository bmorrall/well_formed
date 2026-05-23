# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SimpleForm::Orders", type: :feature do
  scenario "creating and updating an order" do
    # New
    visit new_simple_form_order_path
    expect(page).to have_selector('form[action="/simple_form/orders"]')

    fill_in "order[customer_name]", with: "Alice"
    fill_in "order[line_items_attributes][0][name]", with: "Widget"
    fill_in "order[line_items_attributes][0][quantity]", with: "2"
    fill_in "order[billing_address_attributes][street]", with: "1 Main St"
    fill_in "order[billing_address_attributes][city]", with: "Springfield"
    fill_in "order[billing_address_attributes][postcode]", with: "12345"
    click_button "Create Order"

    # Show (redirects to standard orders show)
    expect(current_path).to match(%r{/orders/\d+\z})
    expect(page).to have_content("Alice")
    expect(page).to have_content("Widget")
    expect(page).to have_content("1 Main St, Springfield, 12345")

    order = Order.last

    # Edit
    visit edit_simple_form_order_path(order)
    expect(current_path).to eq(edit_simple_form_order_path(order))

    fill_in "order[customer_name]", with: "Bob"
    fill_in "order[line_items_attributes][0][name]", with: "Gadget"
    click_button "Update Order"

    # Show after update
    expect(current_path).to match(%r{/orders/\d+\z})
    expect(page).to have_content("Bob")
    expect(page).to have_content("Gadget")
  end

  scenario "showing validation errors on create" do
    visit new_simple_form_order_path

    fill_in "order[customer_name]", with: ""
    fill_in "order[line_items_attributes][0][name]", with: ""
    fill_in "order[line_items_attributes][0][quantity]", with: "0"
    fill_in "order[billing_address_attributes][street]", with: ""
    fill_in "order[billing_address_attributes][city]", with: ""
    fill_in "order[billing_address_attributes][postcode]", with: ""
    click_button "Create Order"

    expect(current_path).to eq(simple_form_orders_path)
    expect(page).to have_css(".order_customer_name span.error", text: "Customer name can't be blank")
    expect(page).to have_css(".order_line_items_name span.error", text: "Name can't be blank")
    expect(page).to have_css(".order_line_items_quantity span.error", text: "Quantity must be greater than 0")
    expect(page).to have_css(".order_billing_address_street span.error", text: "Street can't be blank")
  end

  scenario "showing validation errors on update" do
    visit new_simple_form_order_path
    fill_in "order[customer_name]", with: "Alice"
    fill_in "order[line_items_attributes][0][name]", with: "Widget"
    fill_in "order[line_items_attributes][0][quantity]", with: "2"
    fill_in "order[billing_address_attributes][street]", with: "1 Main St"
    fill_in "order[billing_address_attributes][city]", with: "Springfield"
    fill_in "order[billing_address_attributes][postcode]", with: "12345"
    click_button "Create Order"

    order = Order.last
    visit edit_simple_form_order_path(order)

    fill_in "order[customer_name]", with: ""
    fill_in "order[line_items_attributes][0][name]", with: ""
    fill_in "order[billing_address_attributes][street]", with: ""
    click_button "Update Order"

    expect(current_path).to match(%r{/simple_form/orders/\d+\z})
    expect(page).to have_css(".order_customer_name span.error", text: "Customer name can't be blank")
    expect(page).to have_css(".order_line_items_name span.error", text: "Name can't be blank")
    expect(page).to have_css(".order_billing_address_street span.error", text: "Street can't be blank")
  end
end
