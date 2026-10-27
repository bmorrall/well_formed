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
  describe "#policy" do
    it "returns the ArticlePolicy instance" do
      form = a_form_class.new(Article.new(1), a_user_hash(admin: true))

      policy = form.policy

      expect(policy).to be_a(ArticlePolicy)
    end

    it "passes user and record to the policy" do
      article = Article.new(1)
      admin = a_user_hash(admin: true)
      form = a_form_class.new(article, admin)

      policy = form.policy

      expect(policy.user).to eq(admin)
      expect(policy.record).to eq(article)
    end

    it "uses an explicit record when provided" do
      other_article = Article.new(2)
      form = a_form_class.new(Article.new(1), a_user_hash(admin: true))

      policy = form.policy(other_article)

      expect(policy.record).to eq(other_article)
    end
  end

  describe "#authorize!" do
    it "does not raise when the user is authorized" do
      form = a_form_class.new(Article.new(1), a_user_hash(admin: true))

      expect { form.authorize!(:update?) }.not_to raise_error
    end

    it "accepts an explicit record as the first argument" do
      other_article = Article.new(2)
      form = a_form_class.new(Article.new(1), a_user_hash(admin: true))

      expect { form.authorize!(other_article, :update?) }.not_to raise_error
    end

    it "raises Pundit::NotAuthorizedError when the user is not authorized" do
      form = a_form_class.new(Article.new(1), a_user_hash(admin: false))

      expect { form.authorize!(:update?) }.to raise_error(::Pundit::NotAuthorizedError)
    end
  end

  describe "#policy_scope" do
    it "returns :all when the user is an admin" do
      form = a_form_class.new(Article.new(1), a_user_hash(admin: true))

      scope = form.policy_scope(Article)

      expect(scope).to eq(:all)
    end

    it "returns :restricted when the user is a guest" do
      form = a_form_class.new(Article.new(1), a_user_hash(admin: false))

      scope = form.policy_scope(Article)

      expect(scope).to eq(:restricted)
    end
  end

  def a_form_class
    stub_const("UpdateArticleForm", Class.new(WellFormed::ResourceForm) do
      attribute :title, :string
    end)
  end

  def a_user_hash(admin:) = {admin:}
end
