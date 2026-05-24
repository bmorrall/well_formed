# frozen_string_literal: true

module Api
  class OrdersController < BaseController
    # POST /api/orders
    def create
      order = Order.new
      @form = CreateOrderForm.new(order, current_user, order_params)
      if @form.save
        render json: {id: order.id, customer_name: order.customer_name}, status: :created
      else
        render json: Halitosis::ErrorsSerializer.new(@form),
          status: :unprocessable_content
      end
    end

    # PATCH /api/orders/:id
    def update
      order = Order.find(params.require(:id))
      @form = UpdateOrderForm.new(order, current_user, order_params)
      if @form.save
        render json: {id: order.id, customer_name: order.customer_name}, status: :ok
      else
        render json: Halitosis::ErrorsSerializer.new(@form),
          status: :unprocessable_content
      end
    end

    private

    def order_params
      params.require(:order).permit(:customer_name,
        line_items: [:id, :name, :quantity, :_destroy],
        billing_address: [:street, :city, :postcode])
    end
  end
end
