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
    end)
  end

  describe "#save" do
    context "when valid" do
      it "returns true" do
        form = form_class.new(resource, {name: "Alice", email: "alice@example.com"})
        expect(form.save).to be(true)
      end

      it "assigns matching attributes to the resource" do
        form = form_class.new(resource, {name: "Alice", email: "alice@example.com"})
        form.save
        expect(resource.assigned_attributes).to eq("name" => "Alice", "email" => "alice@example.com")
      end

      it "skips attributes the resource has no setter for" do
        form_class.attribute :extra, :string
        form = form_class.new(resource, {name: "Alice", email: "alice@example.com", extra: "ignored"})
        form.save
        expect(resource.assigned_attributes.keys).not_to include("extra")
      end

      it "does not assign form attr_writer attributes to the resource" do
        form_class.attr_writer :agree_to_terms
        form = form_class.new(resource, {name: "Alice", agree_to_terms: "1"})
        form.save
        expect(resource.assigned_attributes.keys).not_to include("agree_to_terms")
      end

      it "does not assign form attr_accessor attributes to the resource" do
        form_class.attr_accessor :agree_to_terms
        form = form_class.new(resource, {name: "Alice", agree_to_terms: "1"})
        form.save
        expect(form.agree_to_terms).to eq("1")
        expect(resource.assigned_attributes.keys).not_to include("agree_to_terms")
      end

      context "with unmatched_attributes :warn" do
        it "emits a warning and still saves" do
          form_class.attribute :extra, :string
          form_class.unmatched_attributes :warn
          form = form_class.new(resource, {name: "Alice", extra: "ignored"})
          expect { form.save }.to output(/extra/).to_stderr
          expect(resource.assigned_attributes.keys).not_to include("extra")
        end
      end

      context "with unmatched_attributes :raise" do
        it "raises UnmatchedAttributesError listing the unmatched attributes" do
          form_class.attribute :extra, :string
          form_class.unmatched_attributes :raise
          form = form_class.new(resource, {name: "Alice", extra: "ignored"})
          expect { form.save }.to raise_error(WellFormed::UnmatchedAttributesError, /extra/)
        end
      end

      context "with unmatched_attributes :ignore (default)" do
        it "raises ArgumentError for an invalid policy" do
          expect { form_class.unmatched_attributes :bad }.to raise_error(ArgumentError)
        end
      end

      it "calls save on the resource" do
        form = form_class.new(resource, {name: "Alice", email: "alice@example.com"})
        expect(resource).to receive(:save).and_return(true)
        form.save
      end
    end

    context "when invalid" do
      it "returns false without calling save on the resource" do
        form = form_class.new(resource)
        expect(resource).not_to receive(:save)
        expect(form.save).to be(false)
      end
    end

    context "with callbacks" do
      it "runs before_save after assigning attributes but before resource.save" do
        order = []
        form_class.before_save { order << :before_save }
        form = form_class.new(resource, {name: "Alice"})
        allow(resource).to receive(:save) do
          order << :save
          true
        end
        form.save
        expect(order).to eq([:before_save, :save])
      end

      it "runs before_save with attributes already assigned to the resource" do
        seen_attrs = nil
        form_class.before_save { seen_attrs = resource.assigned_attributes }
        form = form_class.new(resource, {name: "Alice"})
        form.save
        expect(seen_attrs).to include("name" => "Alice")
      end

      it "runs after_save after assigning attributes" do
        order = []
        form_class.after_save { order << :after_save }
        form = form_class.new(resource, {name: "Alice"})
        allow(resource).to receive(:save) do
          order << :save
          true
        end
        form.save
        expect(order).to eq([:save, :after_save])
      end

      it "halts save when a before_save callback throws :abort" do
        form_class.before_save { throw :abort }
        form = form_class.new(resource, {name: "Alice"})
        expect(resource).not_to receive(:save)
        expect(form.save).to be(false)
      end

      it "does not run after_save if resource.save returns false" do
        called = false
        form_class.after_save { called = true }
        allow(resource).to receive(:save).and_return(false)
        form = form_class.new(resource, {name: "Alice"})
        form.save
        expect(called).to be(false)
      end

      it "gives access to resource in method callbacks" do
        form_class.before_save :stamp_creator
        form_class.define_method(:stamp_creator) { resource.instance_variable_set(:@created_by, :stamped) }
        form = form_class.new(resource, {name: "Alice"})
        form.save
        expect(resource.instance_variable_get(:@created_by)).to eq(:stamped)
      end
    end
  end

  describe "#submit" do
    context "when valid" do
      it "returns the resource" do
        form = form_class.new(resource, {name: "Alice"})
        expect(form.submit).to eq(resource)
      end
    end

    context "when invalid" do
      it "returns false" do
        form = form_class.new(resource)
        expect(form.submit).to be(false)
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

    context "when a before_save callback aborts (no validation errors)" do
      it "raises RecordInvalid with a generic message" do
        form_class.before_save { throw :abort }
        form = form_class.new(resource, {name: "Alice"})
        expect { form.save! }.to raise_error(WellFormed::RecordInvalid, "Record invalid")
      end
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

  describe "model error handling" do
    let(:failing_resource) do
      stub_const("FailingResource", Class.new do
        include ActiveModel::Model

        attr_accessor :name, :email

        def assign_attributes(attrs)
          attrs.each { |k, v| public_send(:"#{k}=", v) }
        end

        def save
          errors.add(:email, :invalid, message: "is invalid")
          false
        end
      end).new
    end

    context "without merge_model_errors" do
      it "returns false when resource.save fails" do
        form = form_class.new(failing_resource, {name: "Alice", email: "bad"})
        expect(form.save).to be(false)
      end

      it "adds a generic base error so errors is never empty" do
        form = form_class.new(failing_resource, {name: "Alice", email: "bad"})
        form.save
        expect(form.errors[:base]).to include("could not be saved")
      end
    end

    context "with merge_model_errors" do
      before { form_class.merge_model_errors }

      it "returns false when resource.save fails" do
        form = form_class.new(failing_resource, {name: "Alice", email: "bad"})
        expect(form.save).to be(false)
      end

      it "copies model errors onto the form" do
        form = form_class.new(failing_resource, {name: "Alice", email: "bad"})
        form.save
        expect(form.errors[:email]).to include("is invalid")
      end

      it "does not add a generic base error when model errors were merged" do
        form = form_class.new(failing_resource, {name: "Alice", email: "bad"})
        form.save
        expect(form.errors[:base]).to be_empty
      end
    end
  end

  describe "ReservedMethodGuard" do
    %i[submit submit! save save!].each do |method_name|
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
