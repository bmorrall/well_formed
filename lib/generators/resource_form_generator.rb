# frozen_string_literal: true

require "rails/generators"
require "rails/generators/named_base"

class ResourceFormGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  def create_form_file
    template "form.rb.tt", File.join("app/forms", class_path, "#{base_name}_form.rb")
  end

  private

  def form_class_name
    [*class_path.map(&:camelize), "#{base_name.camelize}Form"].join("::")
  end

  def base_name
    file_name.delete_suffix("_form")
  end

  def resource_alias_name
    base_name
  end
end
