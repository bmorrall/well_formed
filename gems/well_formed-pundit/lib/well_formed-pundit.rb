# frozen_string_literal: true

require "well_formed"
require "pundit"
require_relative "well_formed/pundit/version"
require_relative "well_formed/pundit"

WellFormed::WithUser.register_extension(WellFormed::Pundit)
