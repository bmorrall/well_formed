# frozen_string_literal: true

RSpec.describe WellFormed::SimpleAction do
  let(:form_class) do
    stub_const("NotifyForm", Class.new(WellFormed::SimpleAction) do
      attribute :message, :string
      validates :message, presence: true

      def perform
        true
      end
    end)
  end

  let(:resource) { double("resource") }

  describe "constructor" do
    it "accepts (resource, params)" do
      form = form_class.new(resource, {message: "Hello"})
      expect(form.message).to eq("Hello")
    end

    it "accepts (resource) with no params" do
      form = form_class.new(resource)
      expect(form.resource).to eq(resource)
    end

    it "does not expose user" do
      form = form_class.new(resource)
      expect(form).not_to respond_to(:user)
    end
  end

  describe "#submit" do
    it "calls perform and returns true when valid" do
      form = form_class.new(resource, {message: "Hello"})
      expect(form.submit).to be(true)
    end

    it "returns false when invalid" do
      form = form_class.new(resource)
      expect(form.submit).to be(false)
    end

    it "does not assign attributes to the resource" do
      expect(resource).not_to receive(:assign_attributes)
      expect(resource).not_to receive(:message=)
      form_class.new(resource, {message: "Hello"}).submit
    end

    it "does not include Persistence" do
      expect(form_class.ancestors).not_to include(WellFormed::Persistence)
    end
  end

  describe "callbacks" do
    it "runs before_perform before perform" do
      order = []
      form_class.before_perform { order << :before_perform }
      form_class.define_method(:perform) { order << :perform }
      form_class.new(resource, {message: "Hi"}).submit
      expect(order).to eq([:before_perform, :perform])
    end

    it "runs after_perform after perform" do
      order = []
      form_class.after_perform { order << :after_perform }
      form_class.define_method(:perform) { order << :perform }
      form_class.new(resource, {message: "Hi"}).submit
      expect(order).to eq([:perform, :after_perform])
    end

    it "halts when a before_perform callback throws :abort" do
      form_class.before_perform { throw :abort }
      form = form_class.new(resource, {message: "Hi"})
      expect(form.submit).to be(false)
      expect(form.errors[:base]).to eq(["could not be performed"])
    end
  end

  describe "RecordIdentity" do
    it "defaults to create_action (persisted? is false)" do
      expect(form_class.new(resource).persisted?).to be(false)
    end

    it "supports update_action" do
      form_class.update_action
      expect(form_class.new(resource).persisted?).to be(true)
    end
  end

  describe "abstract perform" do
    it "raises NotImplementedError when perform is not implemented" do
      klass = Class.new(WellFormed::SimpleAction)
      form = klass.new(double("resource"))
      expect { form.submit }.to raise_error(NotImplementedError)
    end
  end

  describe "#submit!" do
    it "returns true when valid and perform succeeds" do
      form = form_class.new(resource, {message: "Hello"})
      expect(form.submit!).to be(true)
    end

    it "raises RecordInvalid when invalid" do
      form = form_class.new(resource)
      expect { form.submit! }.to raise_error(WellFormed::RecordInvalid, /Validation failed.*Message/)
    end
  end
end
