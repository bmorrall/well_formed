# frozen_string_literal: true

RSpec.describe WellFormed::Persistence do
  let(:resource) do
    Class.new do
      attr_reader :assigned_attributes

      def assign_attributes(attrs)
        @assigned_attributes = attrs
      end

      def save
        true
      end

      attr_writer :name, :email
    end.new
  end

  let(:form_class) do
    stub_const("PersistenceForm", Class.new do
      include WellFormed

      attribute :name, :string
      attribute :email, :string

      validates :name, presence: true

      private

      def perform
        assign_attributes_to(resource)
        resource.save
      end
    end)
  end

  describe "#save" do
    context "when valid" do
      it "returns true" do
        form = form_class.new(resource, {name: "Alice", email: "alice@example.com"})
        expect(form.save).to be(true)
      end

      it "calls perform" do
        form = form_class.new(resource, {name: "Alice"})
        expect(form).to receive(:perform).and_call_original
        form.save
      end
    end

    context "when invalid" do
      it "returns false without calling perform" do
        form = form_class.new(resource)
        expect(form).not_to receive(:perform)
        expect(form.save).to be(false)
      end
    end

    context "when perform returns falsy" do
      it "returns false and adds a base error" do
        form_class.define_method(:perform) { nil }
        form = form_class.new(resource, {name: "Alice"})
        expect(form.save).to be(false)
        expect(form.errors[:base]).to include("could not be saved")
      end
    end

    context "with callbacks" do
      it "runs before_perform before perform" do
        order = []
        form_class.before_perform { order << :before_perform }
        form_class.define_method(:perform) {
          order << :perform
          true
        }
        form = form_class.new(resource, {name: "Alice"})
        form.save
        expect(order).to eq([:before_perform, :perform])
      end

      it "runs after_perform after perform" do
        order = []
        form_class.after_perform { order << :after_perform }
        form_class.define_method(:perform) {
          order << :perform
          true
        }
        form = form_class.new(resource, {name: "Alice"})
        form.save
        expect(order).to eq([:perform, :after_perform])
      end

      it "halts save when a before_perform callback throws :abort" do
        form_class.before_perform { throw :abort }
        form = form_class.new(resource, {name: "Alice"})
        expect(form).not_to receive(:perform)
        expect(form.save).to be(false)
      end

      it "does not run after_perform if perform returns false" do
        called = false
        form_class.after_perform { called = true }
        form_class.define_method(:perform) { false }
        form = form_class.new(resource, {name: "Alice"})
        form.save
        expect(called).to be(false)
      end

      it "gives access to resource in method callbacks" do
        form_class.before_perform :stamp_creator
        form_class.define_method(:stamp_creator) { resource.instance_variable_set(:@created_by, :stamped) }
        form = form_class.new(resource, {name: "Alice"})
        form.save
        expect(resource.instance_variable_get(:@created_by)).to eq(:stamped)
      end
    end
  end

  describe "#save!" do
    context "when valid" do
      it "returns true" do
        form = form_class.new(resource, {name: "Alice"})
        expect(form.save!).to be(true)
      end
    end

    context "when invalid (validation errors)" do
      it "raises RecordInvalid with the validation messages" do
        form = form_class.new(resource)
        expect { form.save! }.to raise_error(WellFormed::RecordInvalid, /Validation failed.*Name/)
      end

      it "exposes the form as record on the error" do
        form = form_class.new(resource)
        begin
          form.save!
        rescue WellFormed::RecordInvalid => e
          expect(e.record).to be(form)
        end
      end
    end

    context "when a before_perform callback aborts (no validation errors)" do
      it "raises RecordInvalid with a generic message" do
        form_class.before_perform { throw :abort }
        form = form_class.new(resource, {name: "Alice"})
        expect { form.save! }.to raise_error(WellFormed::RecordInvalid, "Validation failed: could not be saved")
      end
    end
  end

  describe "#merge_errors" do
    it "copies errors from another model onto the form" do
      model = stub_const("ErrorSourceModel", Class.new do
        include ActiveModel::Model

        attr_accessor :email
        validates :email, presence: true
      end).new
      model.valid?

      form = form_class.new(resource, {name: "Alice"})
      form.send(:merge_errors, model)

      expect(form.errors[:email]).to include("can't be blank")
    end
  end

  describe "#new_record?" do
    let(:resource_with_persistence) do
      Class.new do
        attr_writer :name, :email

        def assign_attributes(attrs)
          attrs.each { |k, v| public_send(:"#{k}=", v) }
        end

        def save = true
        def persisted? = false
      end.new
    end

    it "returns true when the resource is not persisted" do
      form = form_class.new(resource_with_persistence, {name: "Alice"})
      expect(form.new_record?).to be(true)
    end

    it "returns false when the resource is persisted" do
      allow(resource_with_persistence).to receive(:persisted?).and_return(true)
      form = form_class.new(resource_with_persistence, {name: "Alice"})
      expect(form.new_record?).to be(false)
    end
  end

  describe "without perform defined" do
    it "raises NotImplementedError" do
      klass = stub_const("NoPerformForm", Class.new do
        include WellFormed

        attribute :name, :string
        validates :name, presence: true
      end)
      form = klass.new(resource, {name: "Alice"})
      expect { form.save }.to raise_error(NotImplementedError, /NoPerformForm/)
    end
  end

  describe "ReservedMethodGuard" do
    %i[save save! submit submit!].each do |method_name|
      it "raises ArgumentError when a subclass defines ##{method_name}" do
        expect {
          Class.new(form_class) do
            define_method(method_name) {}
          end
        }.to raise_error(ArgumentError, /#{Regexp.escape(method_name.to_s)}/)
      end
    end
  end
end
