# frozen_string_literal: true

module WellFormed
  module Translations
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def resource_alias(resource)
        resolved = case resource
        when Class
          raise ArgumentError, "#{resource} does not respond to model_name" unless resource.respond_to?(:model_name)

          resource.model_name
        when Symbol, String
          name_str = ActiveSupport::Inflector.camelize(resource.to_s)
          ActiveModel::Name.new(Class.new, nil, name_str)
        else
          raise ArgumentError, "resource_alias expects a Class, Symbol, or String, got #{resource.class}"
        end

        define_singleton_method(:model_name) { resolved }

        alias_name = resolved.element.to_sym
        alias_method alias_name, :resource
      end
    end
  end
end
