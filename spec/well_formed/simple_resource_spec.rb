# frozen_string_literal: true

RSpec.describe WellFormed::SimpleResource do
  let(:form_class) do
    stub_const("CreateThingForm", Class.new(WellFormed::SimpleResource) do
      attribute :title, :string
      validates :title, presence: true
    end)
  end

  let(:resource) { double("resource", title: nil, assign_attributes: nil, save: true) }

  describe "constructor" do
    it "accepts (resource, params)" do
      form = form_class.new(resource, {title: "Hello"})
      expect(form.title).to eq("Hello")
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

  describe "#resource" do
    it "returns the resource" do
      form = form_class.new(resource)
      expect(form.resource).to eq(resource)
    end
  end

  describe "resource_defaults" do
    it "pre-fills attributes from the resource" do
      resource = double("resource", title: "Pre-filled")
      form = form_class.new(resource)
      expect(form.title).to eq("Pre-filled")
    end

    it "params override resource defaults" do
      resource = double("resource", title: "Default")
      form = form_class.new(resource, {title: "Override"})
      expect(form.title).to eq("Override")
    end
  end

  describe "#valid?" do
    it "returns true when attributes are valid" do
      form = form_class.new(resource, {title: "Hello"})
      expect(form.valid?).to be(true)
    end

    it "returns false when attributes are invalid" do
      form = form_class.new(resource)
      expect(form.valid?).to be(false)
    end
  end

  describe "#save" do
    it "assigns attributes to the resource and saves" do
      resource = double("resource")
      allow(resource).to receive(:respond_to?).with("title").and_return(false)
      allow(resource).to receive(:respond_to?).with("title=").and_return(true)
      allow(resource).to receive(:respond_to?).with(:assign_attributes).and_return(true)
      allow(resource).to receive(:assign_attributes)
      allow(resource).to receive(:save).and_return(true)

      form = form_class.new(resource, {title: "Hello"})
      expect(form.save).to be(true)
    end

    it "returns false when invalid" do
      form = form_class.new(resource)
      expect(form.save).to be(false)
    end
  end

  describe "#submit" do
    it "returns the resource on success" do
      resource = double("resource")
      allow(resource).to receive(:respond_to?).with("title").and_return(true)
      allow(resource).to receive(:title).and_return(nil)
      allow(resource).to receive(:respond_to?).with("title=").and_return(true)
      allow(resource).to receive(:respond_to?).with(:assign_attributes).and_return(true)
      allow(resource).to receive(:assign_attributes)
      allow(resource).to receive(:save).and_return(true)

      form = form_class.new(resource, {title: "Hello"})
      expect(form.submit).to eq(resource)
    end

    it "returns false on failure" do
      form = form_class.new(resource)
      expect(form.submit).to be(false)
    end
  end

  describe "callbacks" do
    it "runs before_save before persisting" do
      order = []
      form_class.before_save { order << :before_save }
      allow(resource).to receive(:respond_to?).with("title").and_return(false)
      allow(resource).to receive(:respond_to?).with("title=").and_return(true)
      allow(resource).to receive(:respond_to?).with(:assign_attributes).and_return(true)
      allow(resource).to receive(:assign_attributes)
      allow(resource).to receive(:save) {
        order << :save
        true
      }

      form_class.new(resource, {title: "Hello"}).save
      expect(order).to eq([:before_save, :save])
    end

    it "runs after_save after persisting" do
      order = []
      form_class.after_save { order << :after_save }
      allow(resource).to receive(:respond_to?).with("title").and_return(false)
      allow(resource).to receive(:respond_to?).with("title=").and_return(true)
      allow(resource).to receive(:respond_to?).with(:assign_attributes).and_return(true)
      allow(resource).to receive(:assign_attributes)
      allow(resource).to receive(:save) {
        order << :save
        true
      }

      form_class.new(resource, {title: "Hello"}).save
      expect(order).to eq([:save, :after_save])
    end
  end

  describe "delegation" do
    it "delegates id to resource" do
      allow(resource).to receive(:id).and_return(42)
      form = form_class.new(resource)
      expect(form.id).to eq(42)
    end

    it "delegates persisted? to resource" do
      allow(resource).to receive(:persisted?).and_return(true)
      form = form_class.new(resource)
      expect(form.persisted?).to be(true)
    end
  end

  describe "collections" do
    it "supports collection_for" do
      klass = stub_const("FormWithCollection", Class.new(WellFormed::SimpleResource) do
        attribute :status, :string
        collection_for :status do
          ["draft", "published"]
        end
      end)
      form = klass.new(double("resource", status: nil))
      expect(form.collection_for_status).to eq(["draft", "published"])
    end
  end
end
