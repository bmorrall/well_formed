# frozen_string_literal: true

RSpec.describe WellFormed::SimpleStruct do
  let(:form_class) do
    stub_const("ProcessThingForm", Class.new(WellFormed::SimpleStruct) do
      attribute :email, :string
      validates :email, presence: true

      private

      def perform
        resource.email = email
        true
      end
    end)
  end

  let(:resource) { double("resource", email: nil) }

  describe "constructor" do
    it "accepts (resource, params)" do
      form = form_class.new(resource, {email: "a@b.com"})
      expect(form.email).to eq("a@b.com")
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

  describe "#save / #submit" do
    it "calls perform and returns true when valid" do
      allow(resource).to receive(:email=)
      form = form_class.new(resource, {email: "a@b.com"})
      expect(form.save).to be(true)
    end

    it "returns false when invalid" do
      form = form_class.new(resource)
      expect(form.save).to be(false)
    end

    it "submit returns the resource on success" do
      allow(resource).to receive(:email=)
      form = form_class.new(resource, {email: "a@b.com"})
      expect(form.submit).to eq(resource)
    end
  end

  describe "PoroInterface" do
    it "id delegates to resource when available" do
      allow(resource).to receive(:id).and_return(7)
      form = form_class.new(resource)
      expect(form.id).to eq(7)
    end

    it "id returns nil when resource does not respond to id" do
      resource = Object.new
      form = form_class.new(resource)
      expect(form.id).to be_nil
    end

    it "persisted? delegates to resource when available" do
      allow(resource).to receive(:persisted?).and_return(false)
      form = form_class.new(resource)
      expect(form.persisted?).to be(false)
    end

    it "persisted? returns false when resource does not respond to persisted?" do
      resource = Object.new
      form = form_class.new(resource)
      expect(form.persisted?).to be(false)
    end
  end

  describe "abstract perform" do
    it "raises NotImplementedError if subclass does not define perform" do
      klass = Class.new(WellFormed::SimpleStruct) do
        attribute :name, :string
      end
      form = klass.new(double("resource", name: nil), {name: "test"})
      expect { form.save }.to raise_error(NotImplementedError)
    end
  end

  describe "callbacks" do
    it "runs before_save and after_save" do
      order = []
      form_class.before_save { order << :before_save }
      form_class.after_save { order << :after_save }
      allow(resource).to receive(:email=)
      form_class.new(resource, {email: "a@b.com"}).save
      expect(order).to eq([:before_save, :after_save])
    end
  end
end
