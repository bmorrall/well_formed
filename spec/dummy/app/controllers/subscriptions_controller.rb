# frozen_string_literal: true

class SubscriptionsController < ApplicationController
  layout false

  # GET /subscription/new
  def new
    @form = CreateSubscriptionForm.new(Subscription.new, current_user)
  end

  # POST /subscription
  def create
    @form = CreateSubscriptionForm.new(Subscription.new, current_user, subscription_params)
    if @form.save
      head :created
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def current_user
    @current_user ||= User.first || User.create!(name: "Test User", email: "test@example.com")
  end

  def subscription_params
    params.require(:subscription).permit(:email, :name)
  end
end
