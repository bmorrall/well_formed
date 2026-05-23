# frozen_string_literal: true

RSpec.describe WellFormed::ActionForm do
  let(:form_class) do
    stub_const("PublishForm", Class.new(WellFormed::ActionForm) do
      attribute :reason, :string

      validates :reason, presence: true

      def perform
        true
      end
    end)
  end

  let(:resource) { double("resource") }
  let(:user) { double("user") }

  describe "#submit" do
    context "when valid" do
      it "calls perform and returns true" do
        form = form_class.new(resource, user, {reason: "looks good"})
        expect(form.submit).to be(true)
      end

      it "does not assign attributes to the resource" do
        expect(resource).not_to receive(:assign_attributes)
        expect(resource).not_to receive(:reason=)
        form_class.new(resource, user, {reason: "looks good"}).submit
      end

      it "does not include Persistence" do
        expect(form_class.ancestors).not_to include(WellFormed::Persistence)
      end

      it "exposes resource and user" do
        form = form_class.new(resource, user, {reason: "yes"})
        expect(form.resource).to eq(resource)
        expect(form.user).to eq(user)
      end
    end

    context "when invalid" do
      it "returns false without calling perform" do
        form = form_class.new(resource, user)
        expect(form).not_to receive(:perform)
        expect(form.submit).to be(false)
      end
    end

    context "with callbacks" do
      it "runs before_perform before perform" do
        order = []
        form_class.before_perform { order << :before_perform }
        form_class.define_method(:perform) { order << :perform }
        form = form_class.new(resource, user, {reason: "yes"})
        form.submit
        expect(order).to eq([:before_perform, :perform])
      end

      it "runs after_perform after perform" do
        order = []
        form_class.after_perform { order << :after_perform }
        form_class.define_method(:perform) { order << :perform }
        form = form_class.new(resource, user, {reason: "yes"})
        form.submit
        expect(order).to eq([:perform, :after_perform])
      end

      it "halts submit when a before_perform callback throws :abort" do
        form_class.before_perform { throw :abort }
        form = form_class.new(resource, user, {reason: "yes"})
        expect(form).not_to receive(:perform)
        expect(form.submit).to be(false)
      end

      it "adds a base error when halted with no errors" do
        form_class.before_perform { throw :abort }
        form = form_class.new(resource, user, {reason: "yes"})
        form.submit
        expect(form.errors[:base]).to eq(["could not be performed"])
      end

      it "does not add a base error when halted with errors already present" do
        form_class.before_perform do
          errors.add(:base, "not allowed")
          throw :abort
        end
        form = form_class.new(resource, user, {reason: "yes"})
        form.submit
        expect(form.errors[:base]).to eq(["not allowed"])
      end
    end
  end

  describe "create_action / update_action" do
    context "by default (create_action)" do
      it "persisted? returns false" do
        form = form_class.new(resource, user, {reason: "yes"})
        expect(form.persisted?).to be(false)
      end

      it "id returns nil" do
        form = form_class.new(resource, user, {reason: "yes"})
        expect(form.id).to be_nil
      end

      it "to_param returns nil" do
        form = form_class.new(resource, user, {reason: "yes"})
        expect(form.to_param).to be_nil
      end
    end

    context "with update_action" do
      before { form_class.update_action }

      it "persisted? returns true" do
        form = form_class.new(resource, user, {reason: "yes"})
        expect(form.persisted?).to be(true)
      end

      it "id delegates to resource" do
        allow(resource).to receive(:id).and_return(42)
        form = form_class.new(resource, user, {reason: "yes"})
        expect(form.id).to eq(42)
      end

      it "to_param delegates to resource" do
        allow(resource).to receive(:to_param).and_return("42")
        form = form_class.new(resource, user, {reason: "yes"})
        expect(form.to_param).to eq("42")
      end

      context "with a PORO resource" do
        let(:poro) { Object.new }

        it "id returns nil when resource does not respond to id" do
          form = form_class.new(poro, user, {reason: "yes"})
          expect(form.id).to be_nil
        end
      end
    end
  end
end
