# frozen_string_literal: true

RSpec.describe WellFormed::Persistence do
  describe "#save" do
    context "when valid" do
      it "returns true" do
        form = a_persistence_form_class.new(a_resource, {name: "Alice", email: "alice@example.com"})

        expect(form.save).to be(true)
      end

      it "calls perform" do
        form = a_persistence_form_class.new(a_resource, {name: "Alice"})
        allow(form).to receive(:perform).and_call_original

        form.save

        expect(form).to have_received(:perform)
      end
    end

    it "returns false without calling perform when invalid" do
      form = a_persistence_form_class.new(a_resource)
      allow(form).to receive(:perform)

      result = form.save

      expect(result).to be(false)
      expect(form).not_to have_received(:perform)
    end

    it "returns false and adds a base error when perform returns falsy" do
      form_class = a_persistence_form_class
      form_class.define_method(:perform) { nil }
      form = form_class.new(a_resource, {name: "Alice"})

      result = form.save

      expect(result).to be(false)
      expect(form.errors[:base]).to include("could not be saved")
    end

    context "with callbacks" do
      it "runs before_perform before perform" do
        order = []
        form_class = a_persistence_form_class
        form_class.before_perform { order << :before_perform }
        form_class.define_method(:perform) {
          order << :perform
          true
        }
        form = form_class.new(a_resource, {name: "Alice"})

        form.save

        expect(order).to eq([:before_perform, :perform])
      end

      it "runs after_perform after perform" do
        order = []
        form_class = a_persistence_form_class
        form_class.after_perform { order << :after_perform }
        form_class.define_method(:perform) {
          order << :perform
          true
        }
        form = form_class.new(a_resource, {name: "Alice"})

        form.save

        expect(order).to eq([:perform, :after_perform])
      end

      it "halts save when a before_perform callback throws :abort" do
        form_class = a_persistence_form_class
        form_class.before_perform { throw :abort }
        form = form_class.new(a_resource, {name: "Alice"})
        allow(form).to receive(:perform)

        result = form.save

        expect(result).to be(false)
        expect(form).not_to have_received(:perform)
      end

      it "does not run after_perform if perform returns false" do
        called = false
        form_class = a_persistence_form_class
        form_class.after_perform { called = true }
        form_class.define_method(:perform) { false }
        form = form_class.new(a_resource, {name: "Alice"})

        form.save

        expect(called).to be(false)
      end

      it "gives access to resource in method callbacks" do
        example_resource = a_resource
        form_class = a_persistence_form_class
        form_class.before_perform :stamp_creator
        form_class.define_method(:stamp_creator) { resource.created_by = :stamped }
        form = form_class.new(example_resource, {name: "Alice"})

        form.save

        expect(example_resource.created_by).to eq(:stamped)
      end
    end
  end

  describe "#save!" do
    it "returns true when valid" do
      form = a_persistence_form_class.new(a_resource, {name: "Alice"})

      expect(form.save!).to be(true)
    end

    context "when invalid (validation errors)" do
      it "raises RecordInvalid with the validation messages" do
        form = a_persistence_form_class.new(a_resource)

        expect { form.save! }.to raise_error(WellFormed::RecordInvalid, /Validation failed.*Name/)
      end

      it "exposes the form as record on the error" do
        form = a_persistence_form_class.new(a_resource)

        expect { form.save! }.to raise_error(WellFormed::RecordInvalid) { |error| expect(error.record).to be(form) }
      end
    end

    it "raises RecordInvalid with a generic message when a before_perform callback aborts" do
      form_class = a_persistence_form_class
      form_class.before_perform { throw :abort }
      form = form_class.new(a_resource, {name: "Alice"})

      expect { form.save! }.to raise_error(WellFormed::RecordInvalid, "Validation failed: could not be saved")
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
      form_class = a_persistence_form_class
      form_class.define_method(:perform) {
        merge_errors(model)
        false
      }
      form = form_class.new(a_resource, {name: "Alice"})

      form.save

      expect(form.errors[:email]).to include("can't be blank")
    end
  end

  describe "#new_record?" do
    it "returns true when the resource is not persisted" do
      form = a_persistence_form_class.new(a_resource(persisted: false), {name: "Alice"})

      expect(form.new_record?).to be(true)
    end

    it "returns false when the resource is persisted" do
      form = a_persistence_form_class.new(a_resource(persisted: true), {name: "Alice"})

      expect(form.new_record?).to be(false)
    end
  end

  it "raises NotImplementedError when perform is not defined" do
    form_class = stub_const("NoPerformForm", Class.new do
      include WellFormed

      attribute :name, :string
      validates :name, presence: true
    end)
    form = form_class.new(a_resource, {name: "Alice"})

    expect { form.save }.to raise_error(NotImplementedError, /NoPerformForm/)
  end

  describe "ReservedMethodGuard" do
    %i[save save! submit submit!].each do |method_name|
      it "raises ArgumentError when a subclass defines ##{method_name}" do
        form_class = a_persistence_form_class

        expect {
          Class.new(form_class) do
            define_method(method_name) {}
          end
        }.to raise_error(ArgumentError, /#{Regexp.escape(method_name.to_s)}/)
      end
    end
  end

  def a_persistence_form_class
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

  def a_resource(persisted: false)
    Class.new do
      attr_reader :assigned_attributes
      attr_writer :name, :email
      attr_accessor :created_by

      define_method(:persisted?) { persisted }

      def assign_attributes(attrs)
        @assigned_attributes = attrs
      end

      def save
        true
      end
    end.new
  end
end
