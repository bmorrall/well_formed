# frozen_string_literal: true

RSpec.describe WellFormed::Collections do
  let(:resource) do
    Class.new do
      def assign_attributes(attrs)
        attrs.each { |k, v| public_send(:"#{k}=", v) if respond_to?(:"#{k}=") }
      end

      def save
        true
      end
    end.new
  end

  let(:user) { double("user") }
  let(:collection) { double("collection") }

  def stub_where(coll, field, value, result)
    scoped = double("scoped_collection")
    allow(coll).to receive(:where).with(field => value).and_return(scoped)
    allow(scoped).to receive(:pluck).with(field).and_return(result)
  end

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

      expect(form_class.new(resource)).to respond_to(:collection_for_user_id)
    end
  end

  describe "#collection_for_user_id" do
    it "returns the result of the block" do
      coll = collection

      form_class = stub_const("PostForm", Class.new do
        include WellFormed

        attribute :user_id, :integer

        collection_for :user_id do
          coll
        end
      end)

      expect(form_class.new(resource).collection_for_user_id).to eq(coll)
    end

    it "evaluates in instance scope (resource is accessible)" do
      form_class = stub_const("PostForm", Class.new do
        include WellFormed

        attribute :user_id, :integer

        collection_for :user_id do
          resource
        end
      end)

      form = form_class.new(resource)
      expect(form.collection_for_user_id).to eq(resource)
    end
  end

  describe "validate: true" do
    let(:form_class) do
      coll = collection

      stub_const("PostForm", Class.new do
        include WellFormed

        attribute :user_id, :integer

        collection_for :user_id, validate: true do
          coll
        end
      end)
    end

    it "is valid when the value exists in the collection" do
      stub_where(collection, :id, 1, [1])
      form = form_class.new(resource, {user_id: 1})
      expect(form).to be_valid
    end

    it "is invalid when the value is not in the collection" do
      stub_where(collection, :id, 99, [])
      form = form_class.new(resource, {user_id: 99})
      expect(form).not_to be_valid
      expect(form.errors[:user_id]).to include("is not included in the list")
    end

    it "is valid when the value is nil (allow_blank: true)" do
      form = form_class.new(resource, {user_id: nil})
      expect(form).to be_valid
    end
  end

  describe "validate: :code" do
    let(:form_class) do
      coll = collection

      stub_const("PostForm", Class.new do
        include WellFormed

        attribute :status, :string

        collection_for :status, validate: :code do
          coll
        end
      end)
    end

    it "is valid when the value exists in the collection matched by the custom field" do
      stub_where(collection, :code, "active", ["active"])
      form = form_class.new(resource, {status: "active"})
      expect(form).to be_valid
    end

    it "is invalid when the value is not in the collection" do
      stub_where(collection, :code, "unknown", [])
      form = form_class.new(resource, {status: "unknown"})
      expect(form).not_to be_valid
      expect(form.errors[:status]).to include("is not included in the list")
    end

    it "is valid when the value is blank (allow_blank: true)" do
      form = form_class.new(resource, {status: nil})
      expect(form).to be_valid
    end
  end

  describe "resolves_to:" do
    def stub_find_by(coll, field, value, result)
      allow(coll).to receive(:find_by).with(field => value).and_return(result)
    end

    let(:resource) { persisted_resource.new(nil) }

    let(:persisted_resource) do
      Class.new do
        attr_accessor :user_id

        def initialize(user_id)
          @user_id = user_id
        end

        def respond_to?(name, *args)
          return true if name.to_s == "user_id" || name.to_s == "user_id="
          super
        end

        def assign_attributes(attrs)
          attrs.each { |k, v| public_send(:"#{k}=", v) if respond_to?(:"#{k}=") }
        end

        def save
          true
        end
      end
    end

    let(:form_class) do
      coll = collection

      stub_const("PostForm", Class.new do
        include WellFormed

        attribute :user_id

        collection_for :user_id, validate: :code, resolves_to: :id do
          coll
        end
      end)
    end

    it "resolves the code to id via after_validation when valid" do
      resolved = double("user", id: 42)
      stub_where(collection, :code, "ABC", ["ABC"])
      stub_find_by(collection, :code, "ABC", resolved)

      form = form_class.new(resource, {user_id: "ABC"})
      form.valid?

      expect(form.user_id).to eq(42)
    end

    it "does not transform when validation fails" do
      stub_where(collection, :code, "INVALID", [])
      stub_find_by(collection, :code, "INVALID", nil)

      form = form_class.new(resource, {user_id: "INVALID"})
      form.valid?

      expect(form.user_id).to eq("INVALID")
    end

    it "is nil when blank" do
      form = form_class.new(resource, {user_id: nil})
      form.valid?

      expect(form.user_id).to be_nil
    end

    it "pre-populates user_id with the code from resource_defaults on a persisted resource" do
      stored_user = double("user", code: "ABC")
      stub_find_by(collection, :id, 42, stored_user)

      form = form_class.new(persisted_resource.new(42))

      expect(form.user_id).to eq("ABC")
    end

    it "leaves user_id nil in resource_defaults when resource has no stored value" do
      form = form_class.new(persisted_resource.new(nil))

      expect(form.user_id).to be_nil
    end

    it "resolves_to: true defaults to :id" do
      coll = collection

      klass = stub_const("StatusForm", Class.new do
        include WellFormed

        attribute :user_id

        collection_for :user_id, validate: :code, resolves_to: true do
          coll
        end
      end)

      resolved = double("user", id: 99)
      stub_where(coll, :code, "XYZ", ["XYZ"])
      stub_find_by(coll, :code, "XYZ", resolved)

      form = klass.new(resource, {user_id: "XYZ"})
      form.valid?

      expect(form.user_id).to eq(99)
    end

    it "resolves_to: :uuid uses a custom resolve field" do
      coll = collection

      klass = stub_const("UuidForm", Class.new do
        include WellFormed

        attribute :user_id

        collection_for :user_id, validate: :code, resolves_to: :uuid do
          coll
        end
      end)

      resolved = double("user", uuid: "abc-123")
      stub_where(coll, :code, "ABC", ["ABC"])
      stub_find_by(coll, :code, "ABC", resolved)

      form = klass.new(resource, {user_id: "ABC"})
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

    context "reverse direction (validate: :id, resolves_to: :code)" do
      let(:persisted_currency_resource) do
        Class.new do
          attr_accessor :currency_code

          def initialize(currency_code)
            @currency_code = currency_code
          end

          def respond_to?(name, *args)
            return true if name.to_s == "currency_code" || name.to_s == "currency_code="
            super
          end

          def assign_attributes(attrs)
            attrs.each { |k, v| public_send(:"#{k}=", v) if respond_to?(:"#{k}=") }
          end

          def save
            true
          end
        end
      end

      let(:reverse_form_class) do
        coll = collection

        stub_const("CurrencyForm", Class.new do
          include WellFormed

          attribute :currency_code

          collection_for :currency_code, validate: :id, resolves_to: :code do
            coll
          end
        end)
      end

      it "resolves the id to code when valid" do
        resolved = double("currency", code: "USD")
        stub_find_by(collection, :id, 1, resolved)

        form = reverse_form_class.new(persisted_currency_resource.new(nil), {currency_code: 1})
        form.valid?

        expect(form.currency_code).to eq("USD")
      end

      it "adds an inclusion error when the id is not found" do
        stub_find_by(collection, :id, 999, nil)

        form = reverse_form_class.new(persisted_currency_resource.new(nil), {currency_code: 999})
        form.valid?

        expect(form.errors[:currency_code]).to include("is not included in the list")
        expect(form.currency_code).to eq(999)
      end

      it "does not transform when blank" do
        form = reverse_form_class.new(persisted_currency_resource.new(nil), {currency_code: nil})
        form.valid?

        expect(form.currency_code).to be_nil
      end

      it "pre-populates currency_code with the id from resource_defaults on a persisted resource" do
        stored_currency = double("currency", id: 1)
        stub_find_by(collection, :code, "USD", stored_currency)

        form = reverse_form_class.new(persisted_currency_resource.new("USD"))

        expect(form.currency_code).to eq(1)
      end

      it "leaves currency_code nil when resource has no stored value" do
        form = reverse_form_class.new(persisted_currency_resource.new(nil))

        expect(form.currency_code).to be_nil
      end
    end
  end

  describe "attribute array: true" do
    describe "without validate:" do
      let(:form_class) do
        coll = collection

        stub_const("TagForm", Class.new do
          include WellFormed

          attribute :tag_ids, array: true

          collection_for :tag_ids do
            coll
          end
        end)
      end

      it "defines a collection_for_tag_ids method" do
        expect(form_class.new(resource)).to respond_to(:collection_for_tag_ids)
      end

      it "returns the collection from the block" do
        form = form_class.new(resource, {tag_ids: [1, 2]})
        expect(form.collection_for_tag_ids).to eq(collection)
      end

      it "accepts an array value on the attribute" do
        form = form_class.new(resource, {tag_ids: [1, 2, 3]})
        expect(form.tag_ids).to eq([1, 2, 3])
      end
    end

    describe "with validate: true" do
      let(:form_class) do
        coll = collection

        stub_const("TagForm", Class.new do
          include WellFormed

          attribute :tag_ids, array: true

          collection_for :tag_ids, validate: true do
            coll
          end
        end)
      end

      it "is valid when all values exist in the collection" do
        stub_where(collection, :id, [1, 2], [1, 2])
        form = form_class.new(resource, {tag_ids: [1, 2]})
        expect(form).to be_valid
      end

      it "is invalid when any value is not in the collection" do
        stub_where(collection, :id, [1, 99], [1])
        form = form_class.new(resource, {tag_ids: [1, 99]})
        expect(form).not_to be_valid
        expect(form.errors[:tag_ids]).to include("is not included in the list")
      end

      it "is valid when the array is empty (allow_blank: true)" do
        form = form_class.new(resource, {tag_ids: []})
        expect(form).to be_valid
      end

      it "is valid when the value is nil (allow_blank: true)" do
        form = form_class.new(resource, {tag_ids: nil})
        expect(form).to be_valid
      end
    end

    describe "with validate: :code" do
      let(:form_class) do
        coll = collection

        stub_const("TagForm", Class.new do
          include WellFormed

          attribute :tag_codes, array: true

          collection_for :tag_codes, validate: :code do
            coll
          end
        end)
      end

      it "is valid when all values exist matched by the custom field" do
        stub_where(collection, :code, %w[alpha beta], %w[alpha beta])
        form = form_class.new(resource, {tag_codes: %w[alpha beta]})
        expect(form).to be_valid
      end

      it "is invalid when any value is not matched by the custom field" do
        stub_where(collection, :code, %w[alpha unknown], %w[alpha])
        form = form_class.new(resource, {tag_codes: %w[alpha unknown]})
        expect(form).not_to be_valid
        expect(form.errors[:tag_codes]).to include("is not included in the list")
      end

      it "is valid when the array is empty (allow_blank: true)" do
        form = form_class.new(resource, {tag_codes: []})
        expect(form).to be_valid
      end
    end
  end
end
