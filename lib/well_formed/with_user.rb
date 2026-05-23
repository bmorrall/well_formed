# frozen_string_literal: true

module WellFormed
  module WithUser
    @extensions = []

    def self.register_extension(mod)
      @extensions << mod
    end

    def self.prepended(base)
      base.extend(ClassMethods)
      @extensions.each { |mod| base.include(mod) }
    end

    def self.included(base)
      raise ArgumentError, "#{name} must be prepended, not included. Use `prepend #{name}` instead."
    end

    module ClassMethods
      # Builds an anonymous nested form class rooted at NestedForm.
      def _nested_form_builder(synthetic_name, &block)
        form_class = Class.new(WellFormed::NestedForm, &block)
        form_class.define_singleton_method(:model_name) do
          ActiveModel::Name.new(self, nil, synthetic_name)
        end
        form_class
      end
    end

    attr_reader :user

    # Instantiates a nested form with the current user.
    def _build_nested_form(form_class, resource, attrs = {})
      form_class.new(resource, user, attrs)
    end

    def initialize(resource, user, params = {})
      @user = user
      super(resource, params)
    end
  end
end
