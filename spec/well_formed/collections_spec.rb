# frozen_string_literal: true

RSpec.describe WellFormed::Collections do
  describe ".collection_for" do
    it "raises ArgumentError when no block is given" do
      expect {
        Class.new do
          include WellFormed

          attribute :user_id, :integer

          collection_for :user_id
        end
      }.to raise_error(ArgumentError, /requires a block/)
    end

    it "defines a collection_for_<name> instance method" do
      form_class = stub_const("PostForm", Class.new do
        include WellFormed

        attribute :user_id, :integer

        collection_for :user_id do
          []
        end
      end)

      form = form_class.new(a_record)

      expect(form).to respond_to(:collection_for_user_id)
    end
  end

  describe "#collection_for_user_id" do
    it "returns the result of the block" do
      users = a_collection
      form_class = stub_const("PostForm", Class.new do
        include WellFormed

        attribute :user_id, :integer

        collection_for :user_id do
          users
        end
      end)

      form = form_class.new(a_record)

      expect(form.collection_for_user_id).to eq(users)
    end

    it "evaluates in instance scope (resource is accessible)" do
      example_resource = a_record
      form_class = stub_const("PostForm", Class.new do
        include WellFormed

        attribute :user_id, :integer

        collection_for :user_id do
          resource
        end
      end)

      form = form_class.new(example_resource)

      expect(form.collection_for_user_id).to eq(example_resource)
    end
  end

  context "with validate: true" do
    let(:form_class) do
      users = a_collection(a_record(id: 1, code: "ABC"))

      stub_const("PostForm", Class.new do
        include WellFormed

        attribute :user_id, :integer

        collection_for :user_id, validate: true do
          users
        end
      end)
    end

    it "is valid when the value exists in the collection" do
      form = form_class.new(a_record, {user_id: 1})

      expect(form).to be_valid
    end

    it "is invalid when the value is not in the collection" do
      form = form_class.new(a_record, {user_id: 99})

      expect(form).not_to be_valid
      expect(form.errors[:user_id]).to include("is not included in the list")
    end

    it "is valid when the value is nil (allow_blank: true)" do
      form = form_class.new(a_record, {user_id: nil})

      expect(form).to be_valid
    end
  end

  context "with validate: :code" do
    let(:form_class) do
      statuses = a_collection(a_record(id: 1, code: "active"))

      stub_const("PostForm", Class.new do
        include WellFormed

        attribute :status, :string

        collection_for :status, validate: :code do
          statuses
        end
      end)
    end

    it "is valid when the value exists in the collection matched by the custom field" do
      form = form_class.new(a_record, {status: "active"})

      expect(form).to be_valid
    end

    it "is invalid when the value is not in the collection" do
      form = form_class.new(a_record, {status: "unknown"})

      expect(form).not_to be_valid
      expect(form.errors[:status]).to include("is not included in the list")
    end

    it "is valid when the value is blank (allow_blank: true)" do
      form = form_class.new(a_record, {status: nil})

      expect(form).to be_valid
    end
  end

  describe "resolves_to:" do
    context "with validate: :code, resolves_to: :id" do
      let(:form_class) do
        users = a_collection(a_record(id: 42, code: "ABC"))

        stub_const("PostForm", Class.new do
          include WellFormed

          attribute :user_id

          collection_for :user_id, validate: :code, resolves_to: :id do
            users
          end
        end)
      end

      it "resolves the code to id via after_validation when valid" do
        form = form_class.new(a_record(user_id: nil), {user_id: "ABC"})

        form.valid?

        expect(form.user_id).to eq(42)
      end

      it "does not transform and adds an inclusion error when validation fails" do
        form = form_class.new(a_record(user_id: nil), {user_id: "INVALID"})

        form.valid?

        expect(form.user_id).to eq("INVALID")
        expect(form.errors[:user_id]).to include("is not included in the list")
      end

      it "is nil when blank" do
        form = form_class.new(a_record(user_id: nil), {user_id: nil})

        form.valid?

        expect(form.user_id).to be_nil
      end

      it "pre-populates user_id with the code from resource_defaults on a persisted resource" do
        form = form_class.new(a_record(user_id: 42))

        expect(form.user_id).to eq("ABC")
      end

      it "leaves user_id nil in resource_defaults when resource has no stored value" do
        form = form_class.new(a_record(user_id: nil))

        expect(form.user_id).to be_nil
      end
    end

    context "with validate: :id, resolves_to: :code (reverse direction)" do
      let(:form_class) do
        currencies = a_collection(a_record(id: 1, code: "USD"))

        stub_const("CurrencyForm", Class.new do
          include WellFormed

          attribute :currency_code

          collection_for :currency_code, validate: :id, resolves_to: :code do
            currencies
          end
        end)
      end

      it "resolves the id to code when valid" do
        form = form_class.new(a_record(currency_code: nil), {currency_code: 1})

        form.valid?

        expect(form.currency_code).to eq("USD")
      end

      it "adds an inclusion error when the id is not found" do
        form = form_class.new(a_record(currency_code: nil), {currency_code: 999})

        form.valid?

        expect(form.errors[:currency_code]).to include("is not included in the list")
        expect(form.currency_code).to eq(999)
      end

      it "does not transform when blank" do
        form = form_class.new(a_record(currency_code: nil), {currency_code: nil})

        form.valid?

        expect(form.currency_code).to be_nil
      end

      it "pre-populates currency_code with the id from resource_defaults on a persisted resource" do
        form = form_class.new(a_record(currency_code: "USD"))

        expect(form.currency_code).to eq(1)
      end

      it "leaves currency_code nil when resource has no stored value" do
        form = form_class.new(a_record(currency_code: nil))

        expect(form.currency_code).to be_nil
      end
    end

    it "defaults resolves_to: true to :id" do
      users = a_collection(a_record(id: 99, code: "XYZ"))
      form_class = stub_const("StatusForm", Class.new do
        include WellFormed

        attribute :user_id

        collection_for :user_id, validate: :code, resolves_to: true do
          users
        end
      end)
      form = form_class.new(a_record(user_id: nil), {user_id: "XYZ"})

      form.valid?

      expect(form.user_id).to eq(99)
    end

    it "resolves to a custom field with resolves_to: :uuid" do
      users = a_collection(a_record(id: 1, uuid: "abc-123", code: "ABC"))
      form_class = stub_const("UuidForm", Class.new do
        include WellFormed

        attribute :user_id

        collection_for :user_id, validate: :code, resolves_to: :uuid do
          users
        end
      end)
      form = form_class.new(a_record(user_id: nil), {user_id: "ABC"})

      form.valid?

      expect(form.user_id).to eq("abc-123")
    end

    it "raises ArgumentError when resolves_to: is set without a Symbol validate:" do
      expect {
        Class.new do
          include WellFormed

          attribute :user_id

          collection_for :user_id, validate: true, resolves_to: :id do
            []
          end
        end
      }.to raise_error(ArgumentError, /requires validate: <Symbol>/)
    end

    it "raises ArgumentError when resolves_to: is set with validate: false" do
      expect {
        Class.new do
          include WellFormed

          attribute :user_id

          collection_for :user_id, resolves_to: :id do
            []
          end
        end
      }.to raise_error(ArgumentError, /requires validate: <Symbol>/)
    end
  end

  describe "attribute array: true" do
    context "without validate:" do
      let(:tags) { a_collection(a_record(id: 1), a_record(id: 2), a_record(id: 3)) }

      let(:form_class) do
        tags = self.tags

        stub_const("TagForm", Class.new do
          include WellFormed

          attribute :tag_ids, array: true

          collection_for :tag_ids do
            tags
          end
        end)
      end

      it "defines a collection_for_tag_ids method" do
        form = form_class.new(a_record)

        expect(form).to respond_to(:collection_for_tag_ids)
      end

      it "returns the collection from the block" do
        form = form_class.new(a_record, {tag_ids: [1, 2]})

        expect(form.collection_for_tag_ids).to eq(tags)
      end

      it "accepts an array value on the attribute" do
        form = form_class.new(a_record, {tag_ids: [1, 2, 3]})

        expect(form.tag_ids).to eq([1, 2, 3])
      end
    end

    context "with validate: true" do
      let(:form_class) do
        tags = a_collection(a_record(id: 1), a_record(id: 2))

        stub_const("TagForm", Class.new do
          include WellFormed

          attribute :tag_ids, array: true

          collection_for :tag_ids, validate: true do
            tags
          end
        end)
      end

      it "is valid when all values exist in the collection" do
        form = form_class.new(a_record, {tag_ids: [1, 2]})

        expect(form).to be_valid
      end

      it "is invalid when any value is not in the collection" do
        form = form_class.new(a_record, {tag_ids: [1, 99]})

        expect(form).not_to be_valid
        expect(form.errors[:tag_ids]).to include("is not included in the list")
      end

      it "is valid when the array is empty (allow_blank: true)" do
        form = form_class.new(a_record, {tag_ids: []})

        expect(form).to be_valid
      end

      it "is valid when the value is nil (allow_blank: true)" do
        form = form_class.new(a_record, {tag_ids: nil})

        expect(form).to be_valid
      end
    end

    context "with validate: :code" do
      let(:form_class) do
        tags = a_collection(a_record(id: 1, code: "alpha"), a_record(id: 2, code: "beta"))

        stub_const("TagForm", Class.new do
          include WellFormed

          attribute :tag_codes, array: true

          collection_for :tag_codes, validate: :code do
            tags
          end
        end)
      end

      it "is valid when all values exist matched by the custom field" do
        form = form_class.new(a_record, {tag_codes: %w[alpha beta]})

        expect(form).to be_valid
      end

      it "is invalid when any value is not matched by the custom field" do
        form = form_class.new(a_record, {tag_codes: %w[alpha unknown]})

        expect(form).not_to be_valid
        expect(form.errors[:tag_codes]).to include("is not included in the list")
      end

      it "is valid when the array is empty (allow_blank: true)" do
        form = form_class.new(a_record, {tag_codes: []})

        expect(form).to be_valid
      end
    end
  end

  # A plain object exposing the given attributes as readers, used both as the
  # form's resource and as the records inside a_collection.
  def a_record(**attributes)
    Class.new do
      attributes.each do |name, value|
        define_method(name) { value }
      end
    end.new
  end

  # An in-memory stand-in for an ActiveRecord relation, supporting the
  # where / pluck / find_by calls that collection_for makes.
  def a_collection(*records)
    Class.new do
      def initialize(records)
        @records = records
      end

      def where(conditions)
        self.class.new(@records.select { |record| conditions.all? { |field, value| Array(value).include?(record.public_send(field)) } })
      end

      def pluck(field)
        @records.map { |record| record.public_send(field) }
      end

      def find_by(conditions)
        @records.find { |record| conditions.all? { |field, value| record.public_send(field) == value } }
      end
    end.new(records)
  end
end
