# frozen_string_literal: true

RSpec.describe WellFormed::Pundit do
  it "has a version number" do
    expect(described_class::VERSION).not_to be_nil
  end

  describe "auto-include via WithUser" do
    it "is included automatically when WithUser is prepended" do
      form_class = a_form_class

      expect(form_class.ancestors).to include(described_class)
    end
  end

  describe "#policy" do
    it "returns the Pundit policy for the resource and user" do
      resource = a_resource
      user = a_user
      policy_class = a_policy_class
      policy_finder = instance_double(::Pundit::PolicyFinder, policy!: policy_class)
      allow(::Pundit::PolicyFinder).to receive(:new).with(resource).and_return(policy_finder)
      form = a_form_class.new(resource, user)

      policy = form.policy

      expect(policy).to eq(policy_class.new(user, resource))
    end

    it "accepts an explicit record argument" do
      other_record = a_resource
      user = a_user
      policy_class = a_policy_class
      policy_finder = instance_double(::Pundit::PolicyFinder, policy!: policy_class)
      allow(::Pundit::PolicyFinder).to receive(:new).with(other_record).and_return(policy_finder)
      form = a_form_class.new(a_resource, user)

      policy = form.policy(other_record)

      expect(policy).to eq(policy_class.new(user, other_record))
    end
  end

  describe "#authorize!" do
    it "delegates to Pundit.authorize with resource" do
      resource = a_resource
      user = a_user
      allow(::Pundit).to receive(:authorize).and_return(resource)
      form = a_form_class.new(resource, user)

      result = form.authorize!(:create?)

      expect(result).to be(resource)
      expect(::Pundit).to have_received(:authorize).with(user, resource, :create?)
    end

    it "raises Pundit::NotAuthorizedError when not authorized" do
      resource = a_resource
      user = a_user
      allow(::Pundit).to receive(:authorize).with(user, resource, :create?)
        .and_raise(::Pundit::NotAuthorizedError)
      form = a_form_class.new(resource, user)

      expect { form.authorize!(:create?) }.to raise_error(::Pundit::NotAuthorizedError)
    end

    it "accepts an explicit record as the first argument" do
      other_record = a_resource
      user = a_user
      allow(::Pundit).to receive(:authorize).and_return(other_record)
      form = a_form_class.new(a_resource, user)

      result = form.authorize!(other_record, :update?)

      expect(result).to be(other_record)
      expect(::Pundit).to have_received(:authorize).with(user, other_record, :update?)
    end
  end

  describe "#policy_scope" do
    it "resolves the scoped collection for the user" do
      collection = a_resource
      user = a_user
      scope_class = a_scope_class
      scope_finder = instance_double(::Pundit::PolicyFinder, scope!: scope_class)
      allow(::Pundit::PolicyFinder).to receive(:new).with(collection).and_return(scope_finder)
      form = a_form_class.new(a_resource, user)

      resolved = form.policy_scope(collection)

      expect(resolved).to eq([:resolved, user, collection])
    end
  end

  def a_form_class
    stub_const("TestForm", Class.new(WellFormed::ResourceForm) do
      attribute :title, :string
    end)
  end

  def a_policy_class = Struct.new(:user, :record)

  def a_scope_class
    Struct.new(:user, :scope) do
      def resolve = [:resolved, user, scope]
    end
  end

  def a_resource = Object.new

  def a_user = Object.new
end
