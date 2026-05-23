# frozen_string_literal: true

module WellFormed
  module Initializer
    def self.included(base)
      raise ArgumentError, "#{name} must be prepended, not included. Use `prepend #{name}` instead."
    end

    attr_reader :resource

    def initialize(resource, params = {})
      @resource = resource
      super(resource_defaults.merge(params))
      after_initialize if respond_to?(:after_initialize, true)
    end

    delegate :id, :persisted?, :to_param, to: :resource, allow_nil: true

    def new_record? = !persisted?

    private

    def resource_defaults
      return {} unless resource

      self.class.attribute_names.each_with_object({}) do |name, hash|
        hash[name] = resource.public_send(name) if resource.respond_to?(name)
      end
    end
  end
end
