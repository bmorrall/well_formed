# frozen_string_literal: true

require "well_formed"
require "dry-types"
require_relative "well_formed/dry_types/version"
require_relative "well_formed/dry_types"

WellFormed::Extensions.register_extension(WellFormed::DryTypes)
