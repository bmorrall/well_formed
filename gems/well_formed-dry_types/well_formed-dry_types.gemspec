# frozen_string_literal: true

require_relative "lib/well_formed/dry_types/version"

Gem::Specification.new do |spec|
  spec.name = "well_formed-dry_types"
  spec.version = WellFormed::DryTypes::VERSION
  spec.authors = ["Ben Morrall"]
  spec.email = ["bemo56@hotmail.com"]

  spec.summary = "dry-types attribute coercion integration for well_formed"
  spec.homepage = "https://github.com/bmorrall/well_formed"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[spec/ .git Gemfile])
    end
  end

  spec.require_paths = ["lib"]

  spec.add_dependency "well_formed", ">= 0.1.0"
  spec.add_dependency "dry-types", ">= 1.0"
end
