# frozen_string_literal: true

module WellFormed
  module Collections
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      # Declares a scoped collection for a form attribute, with optional inclusion validation
      # and optional code-to-id resolution.
      #
      # Generates a +collection_for_<name>+ instance method that returns an ActiveRecord relation.
      # The block is evaluated in the context of the form instance, so +user+, +resource+, and
      # any other instance methods are available.
      #
      # @param name [Symbol] the attribute name (e.g. :user_id)
      # @param validate [false, true, Symbol] when truthy, adds an inclusion validator.
      #   - +true+   — validates that the attribute value exists in the collection matched by +:id+
      #   - Symbol   — validates matched by the given field (e.g. <tt>validate: :code</tt>)
      # @param resolves_to [false, true, Symbol] when truthy, the attribute accepts the +validate+
      #   field value as external input (e.g. a code string) and resolves it to the +resolves_to+
      #   field value (e.g. integer id) via an +after_validation+ callback. Also overrides
      #   +resource_defaults+ to reverse-populate the attribute with the +validate+ field value
      #   for edit forms. Requires +validate:+ to be a Symbol.
      #   - +true+   — resolves to +:id+
      #   - Symbol   — resolves to the given field (e.g. <tt>resolves_to: :uuid</tt>)
      # @yieldreturn [ActiveRecord::Relation] the scoped collection
      #
      # Example (basic):
      #   class CreatePostForm < WellFormed::ResourceForm
      #     attribute :user_id, :integer
      #
      #     collection_for :user_id, validate: true do
      #       User.all
      #     end
      #   end
      #
      # Example (code-to-id resolution):
      #   class CreatePostForm < WellFormed::ResourceForm
      #     attribute :user_id  # must not be typed :integer — accepts code strings
      #
      #     collection_for :user_id, validate: :code, resolves_to: :id do
      #       User.all
      #     end
      #   end
      def collection_for(name, validate: false, resolves_to: false, &block)
        raise ArgumentError, "collection_for :#{name} requires a block" unless block

        define_method(:"collection_for_#{name}", &block)

        if resolves_to
          unless validate.is_a?(Symbol)
            raise ArgumentError,
              "collection_for :#{name} requires validate: <Symbol> when resolves_to: is set"
          end

          match_field = validate
          resolve_field = (resolves_to == true) ? :id : resolves_to
          collection_method = :"collection_for_#{name}"

          # Define a single validate method that both validates the input field
          # value and, on success, transforms it to the resolve_field value.
          # Uses :validate callbacks (not :validation) which are reliably set up
          # by ActiveModel::Validations in all contexts.
          resolve_method = :"_resolve_#{name}_to_#{resolve_field}"
          resolved_ivar = :"@_#{name}_resolved_from"

          define_method(resolve_method) do
            val = public_send(name)
            return if val.blank?

            # Re-validate from the original input when the value is the one a
            # previous validation resolved it to, so validation is idempotent.
            from, to = instance_variable_get(resolved_ivar)
            val = from if from && val == to

            record = public_send(collection_method).find_by(match_field => val)
            if record.nil?
              errors.add(name, :inclusion)
            else
              resolved = record.public_send(resolve_field)
              public_send(:"#{name}=", resolved)
              # Set after assigning, as the setter clears the cached pair. Snapshot
              # both values so in-place edits through the reader aren't mirrored here.
              instance_variable_set(resolved_ivar, [val.dup, public_send(name).dup])
            end
          end

          validate resolve_method

          resolve_attr = name.to_s

          prepend(Module.new do
            # Any assignment is new input, so forget the previously resolved pair
            define_method(:"#{name}=") do |value|
              remove_instance_variable(resolved_ivar) if instance_variable_defined?(resolved_ivar)
              super(value)
            end

            define_method(:resource_defaults) do
              defaults = super()
              return defaults unless resource.respond_to?(resolve_attr)

              stored = resource.public_send(resolve_attr)
              return defaults if stored.blank?

              code_value = public_send(collection_method)
                .find_by(resolve_field => stored)
                &.public_send(match_field)
              defaults.merge(resolve_attr => code_value)
            end
          end)

          return
        end

        return unless validate

        match_field = (validate == true) ? :id : validate
        collection_method = :"collection_for_#{name}"

        validates name, inclusion: {
          in: ->(record) {
            record.public_send(collection_method).where(match_field => record.public_send(name)).pluck(match_field)
          },
          allow_blank: true
        }
      end
    end
  end
end
