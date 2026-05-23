# frozen_string_literal: true

module WellFormed
  module NestedAttributes
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      # Defines a collection nested form for validating nested attributes on a has_many association.
      #
      # Both `{name}_attributes=` (Rails form_with / form_for) and `{name}=` (API, no suffix)
      # setters are defined automatically — whichever key your params contain will work.
      #
      # @param name [Symbol] the association name (e.g. :line_items)
      # @param form_class [Class, nil] a ResourceForm class. Omit when supplying a block.
      # @yieldparam block inline class body evaluated on an anonymous WellFormed::Base subclass.
      #
      # Records with `_destroy: true` are excluded from validation but forwarded to the resource.
      #
      # Example — inline block:
      #   class CreateOrderForm < WellFormed::Base
      #     include WellFormed::NestedAttributes
      #     nested_attributes_for :line_items do
      #       attribute :name, :string
      #       validates :name, presence: true
      #     end
      #   end
      def nested_attributes_for(name, form_class = nil, &block)
        _register_nested(name, form_class, collection: true, &block)
      end

      # Defines a singular nested form for validating nested attributes on a has_one/belongs_to.
      #
      # Both `{name}_attributes=` and `{name}=` setters are defined automatically.
      #
      # Example — inline block:
      #   class CreateOrderForm < WellFormed::Base
      #     include WellFormed::NestedAttributes
      #     nested_attribute_for :billing_address do
      #       attribute :street, :string
      #       validates :street, presence: true
      #     end
      #   end
      def nested_attribute_for(name, form_class = nil, &block)
        _register_nested(name, form_class, collection: false, &block)
      end

      def registered_nested_attributes
        inherited = superclass.respond_to?(:registered_nested_attributes) ? superclass.registered_nested_attributes : {}
        inherited.merge(@registered_nested_attributes ||= {})
      end

      private

      def _nested_form_builder(synthetic_name, &block)
        form_class = Class.new(WellFormed::SimpleNestedForm, &block)
        form_class.define_singleton_method(:model_name) do
          ActiveModel::Name.new(self, nil, synthetic_name)
        end
        form_class
      end

      def _register_nested(name, form_class, collection:, &block)
        macro = collection ? "nested_attributes_for" : "nested_attribute_for"

        if form_class && block
          raise ArgumentError, "Pass either a form_class or a block to #{macro} :#{name}, not both"
        end

        if block
          synthetic_name = name.to_s.singularize.camelize
          form_class = _nested_form_builder(synthetic_name, &block)
        end

        raise ArgumentError, "A form_class or block is required for #{macro} :#{name}" unless form_class

        (@registered_nested_attributes ||= {})[name] = {form_class: form_class, collection: collection}

        define_method(name) do
          if instance_variable_defined?(:"@#{name}")
            instance_variable_get(:"@#{name}")
          elsif resource.respond_to?(name)
            raw = resource.public_send(name)
            if collection
              Array(raw).map { |r| _build_nested_form(form_class, r) }
            else
              raw ? _build_nested_form(form_class, raw) : nil
            end
          else
            collection ? [] : nil
          end
        end

        define_method(:"#{name}_attributes=") do |raw_attributes|
          _build_nested_attributes(name, raw_attributes)
        end

        define_method(:"#{name}=") do |raw_attributes|
          _build_nested_attributes(name, raw_attributes)
        end

        validate :"_validate_nested_#{name}"

        define_method(:"_validate_nested_#{name}") do
          instances = instance_variable_get(:"@#{name}")
          return unless instances

          config = self.class.registered_nested_attributes[name]

          if config[:collection]
            Array(instances).each_with_index do |nested_form, index|
              next if nested_form.valid?
              nested_form.errors.each do |error|
                attr = :"#{name}[#{index}].#{error.attribute}"
                if error.type.is_a?(Symbol)
                  errors.add(attr, error.type, **error.options.merge(message: error.message))
                else
                  errors.add(attr, error.message)
                end
              end
            end
          else
            return if instances.valid?
            instances.errors.each do |error|
              attr = :"#{name}.#{error.attribute}"
              if error.type.is_a?(Symbol)
                errors.add(attr, error.type, **error.options.merge(message: error.message))
              else
                errors.add(attr, error.message)
              end
            end
          end
        end
        private :"_validate_nested_#{name}"
      end
    end

    # ActiveModel::Error#generate_message always calls read_attribute_for_validation
    # to supply a :value interpolation, even when a custom :message is present.
    # Compound nested attribute names (e.g. :"line_items[0].name") are not real
    # methods on the form — return nil for any attribute scoped under a registered
    # nested association to avoid a NoMethodError.
    def read_attribute_for_validation(attr)
      attr_str = attr.to_s
      nested_names = self.class.registered_nested_attributes.keys.map(&:to_s)
      return nil if nested_names.any? { |name| attr_str.start_with?("#{name}[", "#{name}.") }
      super
    end

    private

    def _build_nested_attributes(name, raw_attributes)
      @_nested_attributes_raw ||= {}
      @_nested_attributes_raw[:"#{name}_attributes"] = raw_attributes

      resource.public_send(:"#{name}_attributes=", raw_attributes) if resource.respond_to?(:"#{name}_attributes=")

      config = self.class.registered_nested_attributes[name]
      form_class = config[:form_class]
      boolean_type = ActiveModel::Type::Boolean.new

      if config[:collection]
        attrs_list = raw_attributes.is_a?(Array) ? raw_attributes : Array(raw_attributes).map { |_, v| v }
        instances = attrs_list.filter_map do |item_attrs|
          item_attrs = item_attrs.to_h.with_indifferent_access
          next if boolean_type.cast(item_attrs["_destroy"])

          sub_resource = _find_collection_resource(name, item_attrs)
          _build_nested_form(form_class, sub_resource, item_attrs.except("id", "_destroy"))
        end
        instance_variable_set(:"@#{name}", instances)
      else
        item_attrs = raw_attributes.to_h.with_indifferent_access
        sub_resource = resource.respond_to?(name) ? resource.public_send(name) : nil
        instance_variable_set(:"@#{name}", _build_nested_form(form_class, sub_resource, item_attrs))
      end
    end

    def _build_nested_form(form_class, resource, attrs = {})
      form_class.new(resource, attrs)
    end

    def _find_collection_resource(name, item_attrs)
      id = item_attrs["id"]
      return nil unless id && resource.respond_to?(name)

      id_str = id.to_s
      resource.public_send(name).find { |r| r.respond_to?(:id) && r.id.to_s == id_str }
    rescue
      nil
    end
  end
end
