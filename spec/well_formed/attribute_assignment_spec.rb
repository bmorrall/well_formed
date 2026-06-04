# frozen_string_literal: true

RSpec.describe WellFormed::AttributeAssignment do
  let(:form_class) do
    Class.new do
      include WellFormed::AttributeAssignment
      include ActiveModel::Attributes

      attribute :name, :string
      attribute :virtual, :string
    end
  end

  let(:ar_resource) do
    Class.new do
      attr_writer :name
      attr_reader :assigned

      def assign_attributes(attrs)
        @assigned = attrs
      end

      def respond_to?(m, *)
        m.to_s == "name=" || super
      end
    end.new
  end

  let(:poro_resource) do
    Class.new do
      attr_accessor :name

      def respond_to?(m, *)
        m.to_s == "name=" || super
      end
    end.new
  end

  describe ".unmatched_attributes" do
    it "raises ArgumentError for an invalid policy" do
      expect {
        form_class.unmatched_attributes(:bad)
      }.to raise_error(ArgumentError, /policy must be/)
    end

    it "accepts :ignore" do
      expect { form_class.unmatched_attributes(:ignore) }.not_to raise_error
    end

    it "accepts :warn" do
      expect { form_class.unmatched_attributes(:warn) }.not_to raise_error
    end

    it "accepts :raise" do
      expect { form_class.unmatched_attributes(:raise) }.not_to raise_error
    end
  end

  describe ".unmatched_attributes_policy" do
    it "defaults to :ignore" do
      expect(form_class.unmatched_attributes_policy).to eq(:ignore)
    end

    it "returns the configured policy" do
      form_class.unmatched_attributes(:warn)
      expect(form_class.unmatched_attributes_policy).to eq(:warn)
    end
  end

  describe "#assign_attributes_to" do
    subject(:form) {
      form_class.new.tap { |f|
        f.name = "Alice"
        f.virtual = "x"
      }
    }

    context "with :ignore policy (default)" do
      it "assigns matched attributes" do
        form.assign_attributes_to(ar_resource)
        expect(ar_resource.assigned).to include("name" => "Alice")
      end

      it "silently skips unmatched attributes" do
        expect { form.assign_attributes_to(ar_resource) }.not_to raise_error
      end
    end

    context "with :warn policy" do
      before { form_class.unmatched_attributes(:warn) }

      it "prints a warning for unmatched attributes" do
        expect { form.assign_attributes_to(ar_resource) }.to output(/virtual/).to_stderr
      end
    end

    context "with :raise policy" do
      before { form_class.unmatched_attributes(:raise) }

      it "raises UnmatchedAttributesError for unmatched attributes" do
        expect { form.assign_attributes_to(ar_resource) }
          .to raise_error(WellFormed::UnmatchedAttributesError, /virtual/)
      end
    end

    context "when the resource does not respond to assign_attributes" do
      it "assigns each matched attribute individually via its setter" do
        form.assign_attributes_to(poro_resource)
        expect(poro_resource.name).to eq("Alice")
      end
    end
  end
end
