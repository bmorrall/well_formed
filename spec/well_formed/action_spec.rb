# frozen_string_literal: true

RSpec.describe WellFormed::ActionForm do
  it "does not include Persistence" do
    expect(described_class.ancestors).not_to include(WellFormed::Persistence)
  end

  describe "#submit" do
    it "calls perform and returns true when valid" do
      form = a_publish_form_class.new(a_resource, a_user, {reason: "looks good"})

      expect(form.submit).to be(true)
    end

    it "does not assign attributes to the resource" do
      resource = a_resource
      allow(resource).to receive(:assign_attributes)
      allow(resource).to receive(:reason=)
      form = a_publish_form_class.new(resource, a_user, {reason: "looks good"})

      form.submit

      expect(resource).not_to have_received(:assign_attributes)
      expect(resource).not_to have_received(:reason=)
    end

    it "exposes resource and user" do
      resource = a_resource
      user = a_user

      form = a_publish_form_class.new(resource, user, {reason: "yes"})

      expect(form.resource).to be(resource)
      expect(form.user).to be(user)
    end

    it "returns false without calling perform when invalid" do
      form = a_publish_form_class.new(a_resource, a_user)
      allow(form).to receive(:perform)

      result = form.submit

      expect(result).to be(false)
      expect(form).not_to have_received(:perform)
    end

    context "with callbacks" do
      it "runs before_perform before perform" do
        order = []
        form_class = a_publish_form_class
        form_class.before_perform { order << :before_perform }
        form_class.define_method(:perform) { order << :perform }
        form = form_class.new(a_resource, a_user, {reason: "yes"})

        form.submit

        expect(order).to eq([:before_perform, :perform])
      end

      it "runs after_perform after perform" do
        order = []
        form_class = a_publish_form_class
        form_class.after_perform { order << :after_perform }
        form_class.define_method(:perform) { order << :perform }
        form = form_class.new(a_resource, a_user, {reason: "yes"})

        form.submit

        expect(order).to eq([:perform, :after_perform])
      end

      it "halts submit when a before_perform callback throws :abort" do
        form_class = a_publish_form_class
        form_class.before_perform { throw :abort }
        form = form_class.new(a_resource, a_user, {reason: "yes"})
        allow(form).to receive(:perform)

        result = form.submit

        expect(result).to be(false)
        expect(form).not_to have_received(:perform)
      end

      it "adds a base error when halted with no errors" do
        form_class = a_publish_form_class
        form_class.before_perform { throw :abort }
        form = form_class.new(a_resource, a_user, {reason: "yes"})

        form.submit

        expect(form.errors[:base]).to eq(["could not be performed"])
      end

      it "does not add a base error when halted with errors already present" do
        form_class = a_publish_form_class
        form_class.before_perform do
          errors.add(:base, "not allowed")
          throw :abort
        end
        form = form_class.new(a_resource, a_user, {reason: "yes"})

        form.submit

        expect(form.errors[:base]).to eq(["not allowed"])
      end
    end

    context "with after_perform_commit" do
      before do
        stub_const("ActiveRecord", Module.new do
          def self.after_all_transactions_commit(&block)
            block.call
          end
        end)
      end

      it "runs the block after a successful submit inside after_all_transactions_commit" do
        committed = []
        form_class = a_publish_form_class
        form_class.after_perform_commit { committed << :committed }
        form = form_class.new(a_resource, a_user, {reason: "yes"})

        form.submit

        expect(committed).to eq([:committed])
      end

      it "does not run the block when submit fails" do
        committed = []
        form_class = a_publish_form_class
        form_class.after_perform_commit { committed << :committed }
        form = form_class.new(a_resource, a_user)

        form.submit

        expect(committed).to be_empty
      end

      it "calls a named method via after_perform_commit" do
        committed = []
        form_class = a_publish_form_class
        form_class.define_method(:on_commit) { committed << :committed }
        form_class.after_perform_commit :on_commit
        form = form_class.new(a_resource, a_user, {reason: "yes"})

        form.submit

        expect(committed).to eq([:committed])
      end
    end
  end

  describe "create_action / update_action" do
    context "by default (create_action)" do
      it "persisted? returns false" do
        form = a_publish_form_class.new(a_resource, a_user, {reason: "yes"})

        expect(form.persisted?).to be(false)
      end

      it "id returns nil" do
        form = a_publish_form_class.new(a_resource(id: 42), a_user, {reason: "yes"})

        expect(form.id).to be_nil
      end

      it "to_param returns nil" do
        form = a_publish_form_class.new(a_resource(to_param: "42"), a_user, {reason: "yes"})

        expect(form.to_param).to be_nil
      end
    end

    context "with update_action" do
      let(:form_class) { a_publish_form_class.tap(&:update_action) }

      it "persisted? returns true" do
        form = form_class.new(a_resource, a_user, {reason: "yes"})

        expect(form.persisted?).to be(true)
      end

      it "id delegates to resource" do
        form = form_class.new(a_resource(id: 42), a_user, {reason: "yes"})

        expect(form.id).to eq(42)
      end

      it "to_param delegates to resource" do
        form = form_class.new(a_resource(to_param: "42"), a_user, {reason: "yes"})

        expect(form.to_param).to eq("42")
      end

      it "id returns nil when resource does not respond to id" do
        form = form_class.new(Object.new, a_user, {reason: "yes"})

        expect(form.id).to be_nil
      end
    end
  end

  describe "ReservedMethodGuard" do
    %i[submit submit!].each do |method_name|
      it "raises ArgumentError when a subclass defines ##{method_name}" do
        form_class = a_publish_form_class

        expect {
          Class.new(form_class) do
            define_method(method_name) {}
          end
        }.to raise_error(ArgumentError, /#{Regexp.escape(method_name.to_s)}/)
      end
    end
  end

  def a_publish_form_class
    stub_const("PublishForm", Class.new(described_class) do
      attribute :reason, :string

      validates :reason, presence: true

      def perform
        true
      end
    end)
  end

  def a_resource(id: nil, to_param: nil)
    Class.new do
      define_method(:id) { id }
      define_method(:to_param) { to_param }
    end.new
  end

  def a_user
    Object.new
  end
end
