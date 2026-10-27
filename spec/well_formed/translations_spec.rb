# frozen_string_literal: true

RSpec.describe WellFormed::Translations do
  describe ".resource_alias" do
    context "with a Class that has model_name" do
      it "uses the class's model_name" do
        article_class = stub_const("Article", Class.new { include ActiveModel::Model })

        form_class = an_article_form_class

        expect(form_class.model_name).to eq(article_class.model_name)
      end

      it "defines a reader using the element name" do
        stub_const("Article", Class.new { include ActiveModel::Model })
        resource = Object.new

        form = an_article_form_class.new(resource)

        expect(form.article).to be(resource)
      end
    end

    it "raises ArgumentError for a Class without model_name" do
      stub_const("PlainClass", Class.new)

      expect {
        Class.new do
          include WellFormed

          resource_alias PlainClass
        end
      }.to raise_error(ArgumentError, /does not respond to model_name/)
    end

    context "with a Symbol" do
      let(:form_class) do
        stub_const("SymbolForm", Class.new do
          include WellFormed

          resource_alias :article
        end)
      end

      it "sets i18n_key from the symbol" do
        expect(form_class.model_name.i18n_key).to eq(:article)
      end

      it "sets human name from the symbol" do
        expect(form_class.model_name.human).to eq("Article")
      end

      it "sets param_key from the symbol" do
        expect(form_class.model_name.param_key).to eq("article")
      end

      it "defines an article reader on instances" do
        resource = Object.new

        form = form_class.new(resource)

        expect(form.article).to be(resource)
      end
    end

    context "with a String" do
      let(:form_class) do
        stub_const("StringForm", Class.new do
          include WellFormed

          resource_alias "article_comment"
        end)
      end

      it "sets i18n_key from the string" do
        expect(form_class.model_name.i18n_key).to eq(:article_comment)
      end

      it "sets human name from the string" do
        expect(form_class.model_name.human).to eq("Article comment")
      end

      it "defines an article_comment reader on instances" do
        resource = Object.new

        form = form_class.new(resource)

        expect(form.article_comment).to be(resource)
      end
    end

    it "accepts a CamelCase String and produces the same result as snake_case" do
      form_class = stub_const("CamelStringForm", Class.new do
        include WellFormed

        resource_alias "ArticleComment"
      end)

      expect(form_class.model_name.i18n_key).to eq(:article_comment)
      expect(form_class.model_name.human).to eq("Article comment")
    end

    it "raises ArgumentError for an invalid argument" do
      expect {
        Class.new do
          include WellFormed

          resource_alias 42
        end
      }.to raise_error(ArgumentError, /expects a Class, Symbol, or String/)
    end

    it "uses error message translation keys from the aliased resource" do
      I18n.backend.store_translations(:en,
        activemodel: {
          errors: {
            models: {
              article: {
                attributes: {
                  name: {blank: "is required for articles"}
                }
              }
            }
          }
        })
      form_class = stub_const("AliasedErrorForm", Class.new do
        include WellFormed

        attribute :name, :string
        validates :name, presence: true
        resource_alias :article
      end)
      form = form_class.new(Object.new)

      form.valid?

      expect(form.errors[:name]).to include("is required for articles")
    ensure
      I18n.reload!
    end

    it "adds resource_alias as a class method when used standalone without full WellFormed" do
      form_class = stub_const("StandaloneForm", Class.new do
        include ActiveModel::Model
        include WellFormed::Translations

        attr_reader :resource

        resource_alias :invoice
      end)

      expect(form_class.model_name.i18n_key).to eq(:invoice)
    end
  end

  def an_article_form_class
    stub_const("ArticleForm", Class.new do
      include WellFormed

      resource_alias Article
    end)
  end
end
