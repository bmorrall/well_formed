# frozen_string_literal: true

# Integration spec: exercises real Pundit policy resolution (no doubles)

Article = Struct.new(:id)

class ArticlePolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def create? = user[:admin]
  def update? = user[:admin]

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      user[:admin] ? :all : :restricted
    end
  end
end

RSpec.describe WellFormed::Pundit, :integration do
  let(:article) { Article.new(1) }
  let(:admin) { {admin: true} }
  let(:guest) { {admin: false} }

  let(:form_class) do
    stub_const("UpdateArticleForm", Class.new(WellFormed::ResourceForm) do
      attribute :title, :string
    end)
  end

  describe "#policy" do
    subject(:form) { form_class.new(article, admin) }

    it "returns the ArticlePolicy instance" do
      expect(form.policy).to be_a(ArticlePolicy)
    end

    it "passes user and record to the policy" do
      expect(form.policy.user).to eq(admin)
      expect(form.policy.record).to eq(article)
    end

    it "uses an explicit record when provided" do
      other_article = Article.new(2)
      expect(form.policy(other_article).record).to eq(other_article)
    end
  end

  describe "#authorize!" do
    context "when the user is authorized" do
      subject(:form) { form_class.new(article, admin) }

      it "does not raise" do
        expect { form.authorize!(:update?) }.not_to raise_error
      end

      it "accepts an explicit record as the first argument" do
        other_article = Article.new(2)
        expect { form.authorize!(other_article, :update?) }.not_to raise_error
      end
    end

    context "when the user is not authorized" do
      subject(:form) { form_class.new(article, guest) }

      it "raises Pundit::NotAuthorizedError" do
        expect { form.authorize!(:update?) }.to raise_error(::Pundit::NotAuthorizedError)
      end
    end
  end

  describe "#policy_scope" do
    context "when the user is an admin" do
      subject(:form) { form_class.new(article, admin) }

      it "returns :all" do
        expect(form.policy_scope(Article)).to eq(:all)
      end
    end

    context "when the user is a guest" do
      subject(:form) { form_class.new(article, guest) }

      it "returns :restricted" do
        expect(form.policy_scope(Article)).to eq(:restricted)
      end
    end
  end
end
