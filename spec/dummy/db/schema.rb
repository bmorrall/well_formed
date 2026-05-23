# frozen_string_literal: true

ActiveRecord::Schema.define do
  create_table :articles, force: true do |t|
    t.string :title
    t.text :body
    t.boolean :published, default: false
    t.timestamps
  end

  create_table :users, force: true do |t|
    t.string :name
    t.string :email
    t.string :code
    t.timestamps
  end

  create_table :posts, force: true do |t|
    t.string :title
    t.text :body
    t.boolean :published, default: false
    t.references :user, null: true, foreign_key: true
    t.string :user_code
    t.timestamps
  end

  create_table :orders, force: true do |t|
    t.string :customer_name
    t.timestamps
  end

  create_table :line_items, force: true do |t|
    t.references :order, null: false, foreign_key: true
    t.string :name
    t.integer :quantity
    t.timestamps
  end

  create_table :billing_addresses, force: true do |t|
    t.references :order, null: false, foreign_key: true
    t.string :street
    t.string :city
    t.string :postcode
    t.timestamps
  end
end
