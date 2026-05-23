# frozen_string_literal: true

RSpec.describe WellFormed::Pundit do
  it "has a version number" do
    expect(WellFormed::Pundit::VERSION).not_to be_nil
  end

  let(:resource) { double("resource") }
  let(:user) { double("user") }

  let(:form_class) do
    stub_const("TestForm", Class.new(WellFormed::ResourceForm) do
      attribute :title, :string
    end)
  end

  subject(:form) { form_class.new(resource, user) }

  describe "auto-include via WithUser" do
    it "is included automatically when WithUser is prepended" do
      expect(form_class.ancestors).to include(WellFormed::Pundit)
    end
  end

  describe "#policy" do
    it "returns the Pundit policy for the resource and user" do
      policy_instance = double("policy_instance")
      policy_class = double("policy_class", new: policy_instance)
      policy_finder = double("policy_finder", policy!: policy_class)

      allow(::Pundit::PolicyFinder).to receive(:new).with(resource).and_return(policy_finder)

      expect(form.policy).to eq(policy_instance)
    end

    it "accepts an explicit record argument" do
      other_record = double("other_record")
      policy_instance = double("policy_instance")
      policy_class = double("policy_class", new: policy_instance)
      policy_finder = double("policy_finder", policy!: policy_class)

      allow(::Pundit::PolicyFinder).to receive(:new).with(other_record).and_return(policy_finder)

      expect(form.policy(other_record)).to eq(policy_instance)
    end
  end

  describe "#authorize!" do
    it "delegates to Pundit.authorize with resource" do
      allow(::Pundit).to receive(:authorize).with(user, resource, :create?).and_return(true)
      expect { form.authorize!(:create?) }.not_to raise_error
    end

    it "raises Pundit::NotAuthorizedError when not authorized" do
      allow(::Pundit).to receive(:authorize).with(user, resource, :create?)
        .and_raise(::Pundit::NotAuthorizedError)
      expect { form.authorize!(:create?) }.to raise_error(::Pundit::NotAuthorizedError)
    end

    it "accepts an explicit record as the first argument" do
      other_record = double("other_record")
      allow(::Pundit).to receive(:authorize).with(user, other_record, :update?).and_return(true)
      expect { form.authorize!(other_record, :update?) }.not_to raise_error
    end
  end

  describe "#policy_scope" do
    it "resolves the scoped collection for the user" do
      collection = double("collection")
      resolved = double("resolved")
      scope_instance = double("scope_instance", resolve: resolved)
      scope_class = double("scope_class", new: scope_instance)
      scope_finder = double("scope_finder", scope!: scope_class)

      allow(::Pundit::PolicyFinder).to receive(:new).with(collection).and_return(scope_finder)

      expect(form.policy_scope(collection)).to eq(resolved)
    end
  end
end
