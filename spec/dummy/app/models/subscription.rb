# frozen_string_literal: true

class Subscription
  attr_accessor :email, :name
  attr_reader :subscribed

  def initialize
    @subscribed = false
  end

  def subscribe!
    @subscribed = true
  end
end
