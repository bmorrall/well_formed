# frozen_string_literal: true

module WellFormed
  module AttributeAssignment
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def unmatched_attributes(policy)
        raise ArgumentError, "policy must be :ignore, :warn, or :raise" unless %i[ignore warn raise].include?(policy)

        @unmatched_attributes_policy = policy
      end

      def unmatched_attributes_policy
        @unmatched_attributes_policy || :ignore
      end
    end

    def assign_attributes_to(resource)
      matched = attributes.select { |attr, _| resource.respond_to?("#{attr}=") }
      unmatched_keys = attributes.keys - matched.keys

      if unmatched_keys.any?
        case self.class.unmatched_attributes_policy
        when :warn
          warn "#{self.class} has attributes with no setter on resource: #{unmatched_keys.join(", ")}"
        when :raise
          raise UnmatchedAttributesError,
            "#{self.class} has attributes with no setter on resource: #{unmatched_keys.join(", ")}"
        end
      end

      if resource.respond_to?(:assign_attributes)
        resource.assign_attributes(matched)
      else
        matched.each { |attr, value| resource.public_send(:"#{attr}=", value) }
      end
    end
  end
end
