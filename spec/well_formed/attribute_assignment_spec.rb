# frozen_string_literal: true

RSpec.describe WellFormed::AttributeAssignment do
  describe ".unmatched_attributes" do
    it "raises ArgumentError for an invalid policy" do
      form_class = a_form_class

      expect {
        form_class.unmatched_attributes(:bad)
      }.to raise_error(ArgumentError, /policy must be/)
    end

    %i[ignore warn raise].each do |policy|
      it "accepts :#{policy}" do
        form_class = a_form_class

        expect { form_class.unmatched_attributes(policy) }.not_to raise_error
      end
    end
  end

  describe ".unmatched_attributes_policy" do
    it "defaults to :ignore" do
      form_class = a_form_class

      expect(form_class.unmatched_attributes_policy).to eq(:ignore)
    end

    it "returns the configured policy" do
      form_class = a_form_class

      form_class.unmatched_attributes(:warn)

      expect(form_class.unmatched_attributes_policy).to eq(:warn)
    end
  end

  describe "#assign_attributes_to" do
    it "assigns matched attributes with the default :ignore policy" do
      form = a_form(name: "Alice", virtual: "x")
      resource = an_assignable_resource

      form.assign_attributes_to(resource)

      expect(resource.assigned).to eq("name" => "Alice")
    end

    it "silently skips unmatched attributes with the default :ignore policy" do
      form = a_form(name: "Alice", virtual: "x")
      resource = an_assignable_resource

      expect { form.assign_attributes_to(resource) }.not_to output.to_stderr
    end

    it "prints a warning for unmatched attributes with the :warn policy" do
      form = a_form(name: "Alice", virtual: "x", policy: :warn)
      resource = an_assignable_resource

      expect { form.assign_attributes_to(resource) }.to output(/virtual/).to_stderr
    end

    it "raises UnmatchedAttributesError for unmatched attributes with the :raise policy" do
      form = a_form(name: "Alice", virtual: "x", policy: :raise)
      resource = an_assignable_resource

      expect { form.assign_attributes_to(resource) }
        .to raise_error(WellFormed::UnmatchedAttributesError, /virtual/)
    end

    it "assigns each matched attribute via its setter when the resource does not respond to assign_attributes" do
      form = a_form(name: "Alice", virtual: "x")
      resource = a_poro_resource

      form.assign_attributes_to(resource)

      expect(resource.name).to eq("Alice")
    end
  end

  def a_form_class
    Class.new do
      include WellFormed::AttributeAssignment
      include ActiveModel::Attributes

      attribute :name, :string
      attribute :virtual, :string
    end
  end

  def a_form(name:, virtual:, policy: :ignore)
    form_class = a_form_class
    form_class.unmatched_attributes(policy)
    form_class.new.tap do |form|
      form.name = name
      form.virtual = virtual
    end
  end

  def an_assignable_resource
    Class.new do
      attr_writer :name
      attr_reader :assigned

      def assign_attributes(attrs)
        @assigned = attrs
      end
    end.new
  end

  def a_poro_resource
    Class.new do
      attr_accessor :name
    end.new
  end
end
