# frozen_string_literal: true

require "active_model"
require_relative "well_formed/version"
require_relative "well_formed/errors"
require_relative "well_formed/railtie" if defined?(Rails::Railtie)

module WellFormed
  autoload :Extensions, "well_formed/extensions"
  autoload :Initializer, "well_formed/initializer"
  autoload :WithUser, "well_formed/with_user"
  autoload :AttributeAssignment, "well_formed/attribute_assignment"
  autoload :Persistence, "well_formed/persistence"
  autoload :Transactional, "well_formed/transactional"
  autoload :Performer, "well_formed/performer"
  autoload :RecordIdentity, "well_formed/record_identity"
  autoload :Translations, "well_formed/translations"
  autoload :NestedAttributes, "well_formed/nested_attributes"
  autoload :Collections, "well_formed/collections"
  autoload :SimpleNestedForm, "well_formed/simple_nested_form"
  autoload :NestedForm, "well_formed/nested_form"
  autoload :SimpleResource, "well_formed/simple_resource"
  autoload :SimpleAction, "well_formed/simple_action"
  autoload :SimpleStruct, "well_formed/simple_struct"
  autoload :ResourceForm, "well_formed/resource_form"
  autoload :ActionForm, "well_formed/action_form"
  autoload :Struct, "well_formed/struct"

  def self.included(base)
    base.include ActiveModel::Model
    base.include ActiveModel::Attributes
    base.include Translations
    base.include Persistence
    base.include Transactional
    base.include Collections
    base.include NestedAttributes
    base.prepend Initializer
    base.include Extensions
  end
end
