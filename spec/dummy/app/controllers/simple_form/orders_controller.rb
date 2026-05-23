# frozen_string_literal: true

module SimpleForm
  class OrdersController < ApplicationController
    layout false

    # GET /simple_form/orders/new
    def new
      order = Order.new
      order.line_items.build
      order.build_billing_address
      @form = CreateOrderForm.new(order, current_user)
    end

    # GET /simple_form/orders/:id/edit
    def edit
      @form = UpdateOrderForm.new(Order.find(params.expect(:id)), current_user)
    end

    # POST /simple_form/orders
    def create
      order = Order.new
      @form = CreateOrderForm.new(order, current_user, order_params)
      if @form.save
        redirect_to order_path(order)
      else
        render :new, status: :unprocessable_content
      end
    end

    # PATCH /simple_form/orders/:id
    def update
      order = Order.find(params.expect(:id))
      @form = UpdateOrderForm.new(order, current_user, order_params)
      if @form.save
        redirect_to order_path(order)
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def order_params
      params.expect(
        order: [:customer_name,
          line_items_attributes: [[:id, :name, :quantity, :_destroy]],
          billing_address_attributes: [:street, :city, :postcode]]
      )
    end
  end
end
