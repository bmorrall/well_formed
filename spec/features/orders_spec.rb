# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Orders", type: :feature do
  scenario "creating and updating an order" do
    # New
    visit new_order_path
    expect(page).to have_selector('form[action="/orders"]')

    fill_in "order[customer_name]", with: "Alice"
    fill_in "order[line_items_attributes][0][name]", with: "Widget"
    fill_in "order[line_items_attributes][0][quantity]", with: "2"
    fill_in "order[billing_address_attributes][street]", with: "1 Main St"
    fill_in "order[billing_address_attributes][city]", with: "Springfield"
    fill_in "order[billing_address_attributes][postcode]", with: "12345"
    click_button "Create Order"

    # Show
    expect(current_path).to match(%r{/orders/\d+\z})
    expect(page).to have_content("Alice")
    expect(page).to have_content("Widget")
    expect(page).to have_content("1 Main St, Springfield, 12345")

    # Edit
    click_link "Edit"
    expect(current_path).to match(%r{/orders/\d+/edit\z})

    fill_in "order[customer_name]", with: "Bob"
    fill_in "order[line_items_attributes][0][name]", with: "Gadget"
    click_button "Update Order"

    # Show after update
    expect(current_path).to match(%r{/orders/\d+\z})
    expect(page).to have_content("Bob")
    expect(page).to have_content("Gadget")
  end

  scenario "showing validation errors on create" do
    visit new_order_path

    fill_in "order[customer_name]", with: ""
    fill_in "order[line_items_attributes][0][name]", with: ""
    fill_in "order[line_items_attributes][0][quantity]", with: "0"
    fill_in "order[billing_address_attributes][street]", with: ""
    fill_in "order[billing_address_attributes][city]", with: ""
    fill_in "order[billing_address_attributes][postcode]", with: ""
    click_button "Create Order"

    expect(current_path).to eq(orders_path)
    expect(page).to have_css("span.customer-name-error", text: "can't be blank")
    expect(page).to have_css("span.line-item-name-error", text: "can't be blank")
    expect(page).to have_css("span.line-item-quantity-error", text: "must be greater than 0")
    expect(page).to have_css("span.billing-street-error", text: "can't be blank")
  end

  scenario "showing validation errors on update" do
    visit new_order_path
    fill_in "order[customer_name]", with: "Alice"
    fill_in "order[line_items_attributes][0][name]", with: "Widget"
    fill_in "order[line_items_attributes][0][quantity]", with: "2"
    fill_in "order[billing_address_attributes][street]", with: "1 Main St"
    fill_in "order[billing_address_attributes][city]", with: "Springfield"
    fill_in "order[billing_address_attributes][postcode]", with: "12345"
    click_button "Create Order"
    click_link "Edit"

    fill_in "order[customer_name]", with: ""
    fill_in "order[line_items_attributes][0][name]", with: ""
    fill_in "order[billing_address_attributes][street]", with: ""
    click_button "Update Order"

    expect(current_path).to match(%r{/orders/\d+\z})
    expect(page).to have_css("span.error", text: "can't be blank")
    expect(page).to have_css("span.line-item-name-error", text: "can't be blank")
    expect(page).to have_css("span.billing-street-error", text: "can't be blank")
  end
end
