# frozen_string_literal: true

module WellFormed
  # Flattens a has_one/belongs_to association's attributes directly onto the form
  # as a single `{name}_attributes` hash attribute, with individual virtual accessors.
  #
  # Attributes declared in the block are surfaced as individual form methods.
  # `form.attributes` returns `{ "billing_address_attributes" => { ... } }` so
  # `assign_attributes_to(resource)` naturally calls `resource.billing_address_attributes=`
  # via AR's `accepts_nested_attributes_for` — with no extra machinery.
  #
  # Example:
  #   class CheckoutForm < WellFormed::ResourceForm
  #     delegated_attribute_for :billing_address do
  #       attribute :street, :string
  #       attribute :city,   :string
  #       validates :street, presence: true
  #     end
  #   end
  #
  #   form.street                 # => resource.billing_address.street (when not set in params)
  #   form.street = "1 Main St"   # packs into billing_address_attributes["street"]
  #   form.attributes             # => { "billing_address_attributes" => { "street" => "1 Main St" } }
  module DelegatedAttributes
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def delegated_attribute_for(name, &block)
        raise ArgumentError, "A block is required for delegated_attribute_for :#{name}" unless block

        # Capture attribute names/types from the block; record any other calls
        # (e.g. validates, validate) for replay on the form class after virtual
        # methods are defined so validators can find the readers they reference.
        deferred_calls = []
        capture_class = Class.new { include ActiveModel::Attributes }
        capture_class.define_singleton_method(:method_missing) do |m, *args, **kwargs, &blk|
          deferred_calls << [m, args, kwargs, blk]
        end
        capture_class.class_eval(&block)
        delegated_attr_names = (capture_class.attribute_names - ["id"]).freeze
        delegated_attr_types = delegated_attr_names.index_with { |n| capture_class.attribute_types[n] }

        # Register the single composite hash attribute.
        attribute :"#{name}_attributes"

        (@registered_delegated_attributes ||= {})[name] = {attribute_names: delegated_attr_names}

        # Define individual virtual getters/setters that delegate into the hash.
        delegated_attr_names.each do |attr_name|
          attr_type = delegated_attr_types[attr_name]

          define_method(attr_name) do
            hash = public_send(:"#{name}_attributes") || {}
            if hash.key?(attr_name.to_s)
              hash[attr_name.to_s]
            else
              nested = resource.respond_to?(name) ? resource.public_send(name) : nil
              nested.respond_to?(attr_name) ? nested.public_send(attr_name) : nil
            end
          end

          define_method(:"#{attr_name}=") do |value|
            cast_value = attr_type.cast(value)
            current = (public_send(:"#{name}_attributes") || {}).dup
            current[attr_name.to_s] = cast_value
            public_send(:"#{name}_attributes=", current)
          end
        end

        # Replay non-attribute calls from the block (validates, validate, etc.)
        # now that the virtual readers are defined and can be found by validators.
        deferred_calls.each do |method_name, args, kwargs, blk|
          public_send(method_name, *args, **kwargs, &blk)
        end
      end

      def registered_delegated_attributes
        inherited = superclass.respond_to?(:registered_delegated_attributes) ? superclass.registered_delegated_attributes : {}
        inherited.merge(@registered_delegated_attributes ||= {})
      end
    end

    # Strip nil delegated hash attributes from the form's attribute set so that
    # the base assign_attributes_to never tries to forward nil to AR's
    # accepts_nested_attributes_for (which would raise ArgumentError).
    # Non-nil hashes are kept and forwarded naturally since the resource responds
    # to `{name}_attributes=` via accepts_nested_attributes_for.
    def attributes
      delegated_keys = self.class.registered_delegated_attributes.keys.map { |n| "#{n}_attributes" }.to_set
      return super if delegated_keys.empty?

      super.reject { |k, v| delegated_keys.include?(k) && v.nil? }
    end
  end
end
