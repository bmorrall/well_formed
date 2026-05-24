# frozen_string_literal: true

class OrdersController < ApplicationController
  layout false

  # GET /orders/:id
  def show
    @order = Order.find(params.require(:id))
  end

  # GET /orders/new
  def new
    order = Order.new
    order.line_items.build
    order.build_billing_address
    @form = CreateOrderForm.new(order, current_user)
  end

  # GET /orders/:id/edit
  def edit
    @form = UpdateOrderForm.new(Order.find(params.require(:id)), current_user)
  end

  # POST /orders
  def create
    order = Order.new
    @form = CreateOrderForm.new(order, current_user, order_params)
    if @form.save
      redirect_to order_path(order)
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH /orders/:id
  def update
    order = Order.find(params.require(:id))
    @form = UpdateOrderForm.new(order, current_user, order_params)
    if @form.save
      redirect_to order_path(order)
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def order_params
    params.require(:order).permit(:customer_name,
      line_items_attributes: [:id, :name, :quantity, :_destroy],
      billing_address_attributes: [:street, :city, :postcode])
  end
end
