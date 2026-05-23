# frozen_string_literal: true

module WellFormed
  module Pundit
    # Returns the Pundit policy instance for the given record (defaults to resource).
    def policy(record = resource)
      ::Pundit::PolicyFinder.new(record).policy!.new(user, record)
    end

    # Returns the scoped collection for the current user.
    def policy_scope(collection)
      ::Pundit::PolicyFinder.new(collection).scope!.new(user, collection).resolve
    end

    # Raises Pundit::NotAuthorizedError if the user is not authorized for the given query.
    # Optionally pass an explicit record as the first argument; defaults to resource.
    def authorize!(record_or_query, query = nil)
      if query.nil?
        ::Pundit.authorize(user, resource, record_or_query)
      else
        ::Pundit.authorize(user, record_or_query, query)
      end
    end
  end
end
