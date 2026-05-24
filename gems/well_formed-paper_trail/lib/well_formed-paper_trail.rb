# frozen_string_literal: true

require "well_formed"
require "paper_trail"
require_relative "well_formed/paper_trail/version"
require_relative "well_formed/paper_trail"

WellFormed::WithUser.register_extension(WellFormed::PaperTrail)
