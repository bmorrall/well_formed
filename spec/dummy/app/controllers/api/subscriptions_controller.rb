# frozen_string_literal: true

module Api
  class SubscriptionsController < BaseController
    # POST /api/subscription
    def create
      form = CreateSubscriptionForm.new(Subscription.new, current_user, subscription_params)

      if (subscription = form.submit)
        render json: {email: subscription.email, name: subscription.name, subscribed: subscription.subscribed}, status: :created
      else
        render json: {errors: form.errors.messages}, status: :unprocessable_content
      end
    end

    private

    def subscription_params
      params.expect(subscription: [:email, :name])
    end
  end
end
