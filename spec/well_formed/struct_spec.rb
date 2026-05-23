# frozen_string_literal: true

RSpec.describe WellFormed::Struct do
  let(:resource) do
    Class.new do
      attr_accessor :name, :email

      def id = nil
      def persisted? = false
      def to_param = nil
    end.new
  end

  let(:form_class) do
    stub_const("StructForm", Class.new(WellFormed::Struct) do
      attribute :name, :string
      attribute :email, :string

      validates :name, presence: true

      def perform
        true
      end
    end)
  end

  let(:user) { double("user") }

  describe "#save" do
    context "when valid" do
      it "returns true" do
        form = form_class.new(resource, user, {name: "Alice", email: "alice@example.com"})
        expect(form.save).to be(true)
      end

      it "assigns matching attributes to the resource before calling perform" do
        form = form_class.new(resource, user, {name: "Alice", email: "alice@example.com"})
        form.save
        expect(resource.name).to eq("Alice")
        expect(resource.email).to eq("alice@example.com")
      end

      it "calls perform" do
        form = form_class.new(resource, user, {name: "Alice"})
        expect(form).to receive(:perform).and_return(true)
        form.save
      end

      it "does not call resource.save" do
        form = form_class.new(resource, user, {name: "Alice"})
        expect(resource).not_to respond_to(:save)
        expect(form.save).to be(true)
      end
    end

    context "when invalid" do
      it "returns false without calling perform" do
        form = form_class.new(resource, user)
        expect(form).not_to receive(:perform)
        expect(form.save).to be(false)
      end
    end

    context "when perform returns falsy" do
      it "returns false" do
        form_class.define_method(:perform) { false }
        form = form_class.new(resource, user, {name: "Alice"})
        expect(form.save).to be(false)
      end
    end

    context "with callbacks" do
      it "runs before_save before perform" do
        order = []
        form_class.before_save { order << :before_save }
        form_class.define_method(:perform) {
          order << :perform
          true
        }
        form = form_class.new(resource, user, {name: "Alice"})
        form.save
        expect(order).to eq([:before_save, :perform])
      end

      it "runs after_save after perform" do
        order = []
        form_class.after_save { order << :after_save }
        form_class.define_method(:perform) {
          order << :perform
          true
        }
        form = form_class.new(resource, user, {name: "Alice"})
        form.save
        expect(order).to eq([:perform, :after_save])
      end

      it "halts save when a before_save callback throws :abort" do
        form_class.before_save { throw :abort }
        form = form_class.new(resource, user, {name: "Alice"})
        expect(form).not_to receive(:perform)
        expect(form.save).to be(false)
      end
    end
  end

  describe "#submit" do
    it "returns the resource on success" do
      form = form_class.new(resource, user, {name: "Alice"})
      expect(form.submit).to eq(resource)
    end

    it "returns false when invalid" do
      form = form_class.new(resource, user)
      expect(form.submit).to be(false)
    end

    it "returns false when perform returns falsy" do
      form_class.define_method(:perform) { false }
      form = form_class.new(resource, user, {name: "Alice"})
      expect(form.submit).to be(false)
    end
  end

  describe "without perform defined" do
    it "raises NotImplementedError" do
      klass = stub_const("NoPerformForm", Class.new(WellFormed::Struct) do
        attribute :name, :string
      end)
      form = klass.new(resource, user, {name: "Alice"})
      expect { form.save }.to raise_error(NotImplementedError, /NoPerformForm/)
    end
  end

  describe "does not include WellFormed::Performer" do
    it "only uses Persistence for its callback infrastructure" do
      expect(form_class.ancestors).not_to include(WellFormed::Performer)
      expect(form_class.ancestors).to include(WellFormed::Persistence)
    end
  end

  describe "PORO compatibility — resource without Rails model methods" do
    let(:bare_resource) do
      Class.new do
        attr_accessor :name
      end.new
    end

    let(:bare_form_class) do
      stub_const("BareForm", Class.new(WellFormed::Struct) do
        attribute :name, :string

        def perform = true
      end)
    end

    it "returns nil for id when resource does not respond to id" do
      form = bare_form_class.new(bare_resource, double("user"))
      expect(form.id).to be_nil
    end

    it "returns false for persisted? when resource does not respond to persisted?" do
      form = bare_form_class.new(bare_resource, double("user"))
      expect(form.persisted?).to be(false)
    end
  end

  describe "#new_record?" do
    it "returns true when the resource is not persisted" do
      form = form_class.new(resource, user, {name: "Alice"})
      expect(form.new_record?).to be(true)
    end

    it "returns false when the resource is persisted" do
      persisted = resource
      allow(persisted).to receive(:persisted?).and_return(true)
      form = form_class.new(persisted, user, {name: "Alice"})
      expect(form.new_record?).to be(false)
    end
  end
end
