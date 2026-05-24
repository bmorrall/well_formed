# frozen_string_literal: true

module WellFormed
  module DryTypes
    def self.included(base)
      base.extend(ClassMethods)
      base.set_callback(:validate, :before, :_coerce_dry_attributes)
    end

    module ClassMethods
      # Declares an attribute whose value is coerced via a dry-types type before
      # validation runs. Any dry-types type is accepted, including constrained,
      # optional, and sum types.
      #
      #   dry_attribute :amount,  Types::Params::Decimal
      #   dry_attribute :status,  Types::String.enum("draft", "published")
      #   dry_attribute :tags,    Types::Strict::Array.of(Types::Strict::String)
      #   dry_attribute :score,   Types::Params::Integer.optional
      #
      # If coercion fails, an error is added to the attribute. Pass +message:+ to
      # use a specific error message or I18n key instead of the dry-types error:
      #
      #   dry_attribute :status, Types::String.enum("draft", "published"), message: :inclusion
      #   dry_attribute :amount, Types::Params::Decimal, message: "must be a number"
      #
      # Coercion runs before validation, so +validates :amount, presence: true+ will
      # still fire for nil values on optional attributes.
      def dry_attribute(name, type, message: nil)
        _dry_attribute_registry[name] = {type: type, message: message}
        attribute name
      end

      # Returns the merged dry-types attribute registry for this class and all ancestors.
      def _dry_attributes
        parent = superclass.respond_to?(:_dry_attributes) ? superclass._dry_attributes : {}
        parent.merge(_dry_attribute_registry)
      end

      private

      def _dry_attribute_registry
        @_dry_attribute_registry ||= {}
      end
    end

    private

    def _coerce_dry_attributes
      self.class._dry_attributes.each do |name, options|
        coerced = options[:type].call(public_send(name))
        public_send(:"#{name}=", coerced)
      rescue ::Dry::Types::CoercionError => e
        errors.add(name, options[:message] || e.message)
      end
    end
  end
end
