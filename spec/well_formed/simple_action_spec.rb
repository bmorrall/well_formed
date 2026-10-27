# frozen_string_literal: true

RSpec.describe WellFormed::SimpleAction do
  it "does not include Persistence" do
    expect(described_class.ancestors).not_to include(WellFormed::Persistence)
  end

  describe "constructor" do
    it "accepts (resource, params)" do
      form = a_notify_form_class.new(a_resource, {message: "Hello"})

      expect(form.message).to eq("Hello")
    end

    it "accepts (resource) with no params" do
      resource = a_resource

      form = a_notify_form_class.new(resource)

      expect(form.resource).to be(resource)
    end

    it "does not expose user" do
      form = a_notify_form_class.new(a_resource)

      expect(form).not_to respond_to(:user)
    end
  end

  describe "#submit" do
    it "calls perform and returns true when valid" do
      form = a_notify_form_class.new(a_resource, {message: "Hello"})

      expect(form.submit).to be(true)
    end

    it "returns false when invalid" do
      form = a_notify_form_class.new(a_resource)

      expect(form.submit).to be(false)
    end

    it "does not assign attributes to the resource" do
      resource = a_resource
      allow(resource).to receive(:assign_attributes)
      allow(resource).to receive(:message=)
      form = a_notify_form_class.new(resource, {message: "Hello"})

      form.submit

      expect(resource).not_to have_received(:assign_attributes)
      expect(resource).not_to have_received(:message=)
    end

    it "raises NotImplementedError when perform is not implemented" do
      form_class = Class.new(described_class)
      form = form_class.new(a_resource)

      expect { form.submit }.to raise_error(NotImplementedError)
    end
  end

  describe "callbacks" do
    it "runs before_perform before perform" do
      order = []
      form_class = a_notify_form_class
      form_class.before_perform { order << :before_perform }
      form_class.define_method(:perform) { order << :perform }
      form = form_class.new(a_resource, {message: "Hi"})

      form.submit

      expect(order).to eq([:before_perform, :perform])
    end

    it "runs after_perform after perform" do
      order = []
      form_class = a_notify_form_class
      form_class.after_perform { order << :after_perform }
      form_class.define_method(:perform) { order << :perform }
      form = form_class.new(a_resource, {message: "Hi"})

      form.submit

      expect(order).to eq([:perform, :after_perform])
    end

    it "halts when a before_perform callback throws :abort" do
      form_class = a_notify_form_class
      form_class.before_perform { throw :abort }
      form = form_class.new(a_resource, {message: "Hi"})

      result = form.submit

      expect(result).to be(false)
      expect(form.errors[:base]).to eq(["could not be performed"])
    end
  end

  describe "RecordIdentity" do
    it "defaults to create_action (persisted? is false)" do
      form = a_notify_form_class.new(a_resource)

      expect(form.persisted?).to be(false)
    end

    it "supports update_action" do
      form_class = a_notify_form_class
      form_class.update_action

      form = form_class.new(a_resource)

      expect(form.persisted?).to be(true)
    end
  end

  describe "#submit!" do
    it "returns true when valid and perform succeeds" do
      form = a_notify_form_class.new(a_resource, {message: "Hello"})

      expect(form.submit!).to be(true)
    end

    it "raises RecordInvalid when invalid" do
      form = a_notify_form_class.new(a_resource)

      expect { form.submit! }.to raise_error(WellFormed::RecordInvalid, /Validation failed.*Message/)
    end
  end

  def a_notify_form_class
    stub_const("NotifyForm", Class.new(described_class) do
      attribute :message, :string
      validates :message, presence: true

      def perform
        true
      end
    end)
  end

  def a_resource
    Object.new
  end
end
