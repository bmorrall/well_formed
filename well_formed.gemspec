# frozen_string_literal: true

require_relative "lib/well_formed/version"

Gem::Specification.new do |spec|
  spec.name = "well_formed"
  spec.version = WellFormed::VERSION
  spec.authors = ["Ben Morrall"]
  spec.email = ["bemo56@hotmail.com"]

  spec.summary = "Form objects for Rails applications."
  spec.description = "WellFormed provides tools to create and manage form objects in Rails applications, including support for nested resources, validations, callbacks, and error handling."
  spec.homepage = "https://github.com/bmorrall/well_formed"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activemodel"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
