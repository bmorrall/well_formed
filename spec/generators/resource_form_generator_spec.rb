# frozen_string_literal: true

require "rails_helper"
require "generator_spec"
require "generators/resource_form_generator"

RSpec.describe ResourceFormGenerator, type: :generator do
  include GeneratorSpec::GeneratorExampleGroup

  destination File.expand_path("../../tmp", __dir__)

  before { prepare_destination }

  context "with a simple name" do
    before { run_generator ["create_article"] }

    it "creates the form file" do
      expect(destination_root).to have_structure {
        directory "app" do
          directory "forms" do
            file "create_article_form.rb"
          end
        end
      }
    end

    it "defines the correct class" do
      expect(destination_root).to have_structure {
        directory "app" do
          directory "forms" do
            file "create_article_form.rb" do
              contains "class CreateArticleForm < WellFormed::ResourceForm"
            end
          end
        end
      }
    end

    it "comments out resource_alias with the base name" do
      expect(destination_root).to have_structure {
        directory "app" do
          directory "forms" do
            file "create_article_form.rb" do
              contains "# resource_alias :create_article"
            end
          end
        end
      }
    end
  end

  context "when the name already ends in _form" do
    before { run_generator ["create_article_form"] }

    it "does not double up the _form suffix in the filename" do
      expect(destination_root).to have_structure {
        directory "app" do
          directory "forms" do
            file "create_article_form.rb"
          end
        end
      }
    end

    it "does not double up Form in the class name" do
      expect(destination_root).to have_structure {
        directory "app" do
          directory "forms" do
            file "create_article_form.rb" do
              contains "class CreateArticleForm < WellFormed::ResourceForm"
            end
          end
        end
      }
    end
  end

  context "when the name is CamelCase" do
    before { run_generator ["CreateArticleForm"] }

    it "does not double up the _form suffix in the filename" do
      expect(destination_root).to have_structure {
        directory "app" do
          directory "forms" do
            file "create_article_form.rb"
          end
        end
      }
    end

    it "does not double up Form in the class name" do
      expect(destination_root).to have_structure {
        directory "app" do
          directory "forms" do
            file "create_article_form.rb" do
              contains "class CreateArticleForm < WellFormed::ResourceForm"
            end
          end
        end
      }
    end
  end

  context "with a nested module path" do
    before { run_generator ["publications/create_article"] }

    it "creates the form file under the module directory" do
      expect(destination_root).to have_structure {
        directory "app" do
          directory "forms" do
            directory "publications" do
              file "create_article_form.rb"
            end
          end
        end
      }
    end

    it "uses the full namespaced class name" do
      expect(destination_root).to have_structure {
        directory "app" do
          directory "forms" do
            directory "publications" do
              file "create_article_form.rb" do
                contains "class Publications::CreateArticleForm < WellFormed::ResourceForm"
              end
            end
          end
        end
      }
    end

    it "comments out resource_alias with the base name only" do
      expect(destination_root).to have_structure {
        directory "app" do
          directory "forms" do
            directory "publications" do
              file "create_article_form.rb" do
                contains "# resource_alias :create_article"
              end
            end
          end
        end
      }
    end
  end
end
