# frozen_string_literal: true

module WellFormed
  module Extensions
    @extensions = []
    @bases = []

    def self.register_extension(mod)
      @extensions << mod
      @bases.each { |base| base.include(mod) }
    end

    def self.included(base)
      @bases << base
      @extensions.each { |mod| base.include(mod) }
    end
  end
end
