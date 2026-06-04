# frozen_string_literal: true

module Api
  class FlatOrdersController < BaseController
    # POST /api/flat_orders
    def create
      order = Order.new
      @form = CreateOrderFlatAddressForm.new(order, current_user, order_params)
      if @form.save
        render json: order_json(order), status: :created
      else
        render json: {errors: @form.errors.messages}, status: :unprocessable_content
      end
    end

    # PATCH /api/flat_orders/:id
    def update
      order = Order.find(params.require(:id))
      @form = CreateOrderFlatAddressForm.new(order, current_user, order_params)
      if @form.save
        render json: order_json(order), status: :ok
      else
        render json: {errors: @form.errors.messages}, status: :unprocessable_content
      end
    end

    private

    def order_params
      params.require(:order).permit(:customer_name, :street, :city, :postcode)
    end

    def order_json(order)
      order.reload
      {
        id: order.id,
        customer_name: order.customer_name,
        street: order.billing_address&.street,
        city: order.billing_address&.city,
        postcode: order.billing_address&.postcode
      }
    end
  end
end
