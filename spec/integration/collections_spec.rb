# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Collections (integration)", type: :integration do
  describe "collection_for resolves_to: (code → id)" do
    let(:form_class) do
      Class.new(WellFormed::ResourceForm) do
        resource_alias :post

        attribute :title, :string
        attribute :user_id

        validates :title, presence: true

        collection_for :user_id, validate: :code, resolves_to: :id do
          User.all
        end

        private

        def perform
          assign_attributes_to(resource)
          resource.save
        end
      end
    end

    context "create — submitting a code resolves to the stored id" do
      it "persists the user's integer id when given a code string" do
        user = User.create!(name: "Alice", email: "alice@example.com", code: "ALICE")

        form = form_class.new(Post.new, nil, {title: "Hello", user_id: "ALICE"})
        form.save
        result = form.resource

        expect(result).to be_a(Post)
        expect(result.user_id).to eq(user.id)
      end

      it "is invalid and does not persist when the code is not in the collection" do
        form = form_class.new(Post.new, nil, {title: "Hello", user_id: "MISSING"})

        expect(form.save).to be(false)
        expect(form.errors[:user_id]).to include("is not included in the list")
        expect(Post.count).to eq(0)
      end

      it "is invalid and does not persist when the user id is provided as an invalid code" do
        user = User.create!(name: "Alice", email: "alice@example.com", code: "ALICE")
        form = form_class.new(Post.new, nil, {title: "Hello", user_id: user.id})

        expect(form.save).to be(false)
        expect(form.errors[:user_id]).to include("is not included in the list")
        expect(Post.count).to eq(0)
      end

      it "is valid and persists with nil user_id (allow_blank)" do
        form = form_class.new(Post.new, nil, {title: "Hello", user_id: nil})

        form.save
        result = form.resource

        expect(result).to be_a(Post)
        expect(result.user_id).to be_nil
      end
    end

    context "edit — resource_defaults pre-populates with the code" do
      it "initialises user_id with the code for an existing post" do
        user = User.create!(name: "Alice", email: "alice@example.com", code: "ALICE")
        existing_post = Post.create!(title: "Old", body: "", user_id: user.id)

        form = form_class.new(existing_post, nil)

        expect(form.user_id).to eq("ALICE")
      end

      it "updates the post when submitted with a new code" do
        user_a = User.create!(name: "Alice", email: "alice@example.com", code: "ALICE")
        user_b = User.create!(name: "Bob", email: "bob@example.com", code: "BOB")
        existing_post = Post.create!(title: "Old", body: "", user_id: user_a.id)

        form = form_class.new(existing_post, nil, {title: "Updated", user_id: "BOB"})
        form.save
        result = form.resource

        expect(result).to be_a(Post)
        expect(existing_post.reload.user_id).to eq(user_b.id)
      end
    end
  end

  describe "collection_for resolves_to: (id → code)" do
    let(:form_class) do
      Class.new(WellFormed::ResourceForm) do
        resource_alias :post

        attribute :title, :string
        attribute :user_code

        validates :title, presence: true

        collection_for :user_code, validate: :id, resolves_to: :code do
          User.all
        end

        private

        def perform
          assign_attributes_to(resource)
          resource.save
        end
      end
    end

    context "create — submitting an id resolves to the stored code" do
      it "persists the user's code string when given an integer id" do
        user = User.create!(name: "Alice", email: "alice@example.com", code: "ALICE")

        form = form_class.new(Post.new, nil, {title: "Hello", user_code: user.id})
        form.save
        result = form.resource

        expect(result).to be_a(Post)
        expect(result.user_code).to eq("ALICE")
      end

      it "is invalid and does not persist when the id is not in the collection" do
        form = form_class.new(Post.new, nil, {title: "Hello", user_code: 9999})

        expect(form.save).to be(false)
        expect(form.errors[:user_code]).to include("is not included in the list")
        expect(Post.count).to eq(0)
      end

      it "is valid and persists with nil user_code (allow_blank)" do
        form = form_class.new(Post.new, nil, {title: "Hello", user_code: nil})
        form.save
        result = form.resource

        expect(result).to be_a(Post)
        expect(result.user_code).to be_nil
      end
    end

    context "edit — resource_defaults pre-populates with the id" do
      it "initialises user_code with the integer id for an existing post" do
        user = User.create!(name: "Alice", email: "alice@example.com", code: "ALICE")
        existing_post = Post.create!(title: "Old", body: "", user_code: "ALICE")

        form = form_class.new(existing_post, nil)

        expect(form.user_code).to eq(user.id)
      end

      it "updates the post when submitted with a new id" do
        User.create!(name: "Alice", email: "alice@example.com", code: "ALICE")
        user_b = User.create!(name: "Bob", email: "bob@example.com", code: "BOB")
        existing_post = Post.create!(title: "Old", body: "", user_code: "ALICE")

        form = form_class.new(existing_post, nil, {title: "Updated", user_code: user_b.id})
        form.save
        result = form.resource

        expect(result).to be_a(Post)
        expect(existing_post.reload.user_code).to eq("BOB")
      end
    end
  end

  describe "collection_for with attribute array: true" do
    before do
      Temping.create(:tag, parent_class: ApplicationRecord) do
        with_columns do |t|
          t.string :name
          t.string :code
          t.timestamps
        end
      end

      Temping.create(:taggable, parent_class: ApplicationRecord) do
        with_columns do |t|
          t.timestamps
        end
      end
    end

    let(:resource) { Taggable.new }

    let(:form_class) do
      Class.new(WellFormed::SimpleResource) do
        resource_alias Tag

        attribute :tag_ids, array: true

        collection_for :tag_ids, validate: true do
          Tag.all
        end

        private

        def perform
          true
        end
      end
    end

    it "is valid when all provided ids exist in the collection" do
      alpha = Tag.create!(name: "Alpha")
      beta = Tag.create!(name: "Beta")

      form = form_class.new(resource, {tag_ids: [alpha.id, beta.id]})

      expect(form).to be_valid
    end

    it "is invalid when any provided id does not exist in the collection" do
      alpha = Tag.create!(name: "Alpha")

      form = form_class.new(resource, {tag_ids: [alpha.id, 99999]})

      expect(form).not_to be_valid
      expect(form.errors[:tag_ids]).to include("is not included in the list")
    end

    it "is valid when tag_ids is empty (allow_blank)" do
      form = form_class.new(resource, {tag_ids: []})

      expect(form).to be_valid
    end

    it "is valid when tag_ids is nil (allow_blank)" do
      form = form_class.new(resource, {tag_ids: nil})

      expect(form).to be_valid
    end

    it "validates against the live collection — ids from deleted records are rejected" do
      tag = Tag.create!(name: "Ephemeral")
      tag_id = tag.id
      tag.destroy

      form = form_class.new(resource, {tag_ids: [tag_id]})

      expect(form).not_to be_valid
      expect(form.errors[:tag_ids]).to include("is not included in the list")
    end

    describe "validate: :code" do
      let(:form_class) do
        Class.new(WellFormed::SimpleResource) do
          resource_alias Tag

          attribute :tag_codes, array: true

          collection_for :tag_codes, validate: :code do
            Tag.all
          end

          private

          def perform
            true
          end
        end
      end

      it "is valid when all provided codes exist in the collection" do
        Tag.create!(name: "Alpha", code: "ALPHA")
        Tag.create!(name: "Beta", code: "BETA")

        form = form_class.new(resource, {tag_codes: %w[ALPHA BETA]})

        expect(form).to be_valid
      end

      it "is invalid when any provided code does not exist" do
        Tag.create!(name: "Alpha", code: "ALPHA")

        form = form_class.new(resource, {tag_codes: %w[ALPHA MISSING]})

        expect(form).not_to be_valid
        expect(form.errors[:tag_codes]).to include("is not included in the list")
      end
    end
  end
end
