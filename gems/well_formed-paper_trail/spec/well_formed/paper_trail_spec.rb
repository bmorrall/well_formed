# frozen_string_literal: true

RSpec.describe WellFormed::PaperTrail do
  it "has a version number" do
    expect(WellFormed::PaperTrail::VERSION).not_to be_nil
  end

  describe "auto-include via WithUser" do
    let(:form_class) do
      stub_const("TestForm", Class.new(WellFormed::ResourceForm) do
        attribute :title, :string
      end)
    end

    it "is included automatically when WithUser is prepended" do
      expect(form_class.ancestors).to include(WellFormed::PaperTrail)
    end
  end

  describe "ResourceForm — around save" do
    let(:resource) { double("resource", save: true) }
    let(:user) { double("user", id: 42) }

    let(:form_class) do
      stub_const("TestResourceForm", Class.new(WellFormed::ResourceForm) do
        attribute :title, :string

        private

        def perform
          resource.save
        end
      end)
    end

    subject(:form) { form_class.new(resource, user) }

    it "calls PaperTrail.request with whodunnit set to user.id.to_s" do
      expect(::PaperTrail).to receive(:request).with(whodunnit: "42") do |**, &block|
        block.call
      end

      form.save
    end

    it "wraps around resource.save so whodunnit is active during the save" do
      order = []

      allow(::PaperTrail).to receive(:request) do |whodunnit:, &block|
        order << :paper_trail_start
        block.call
        order << :paper_trail_end
      end
      allow(resource).to receive(:save) do
        order << :resource_save
        true
      end

      form.save

      expect(order).to eq([:paper_trail_start, :resource_save, :paper_trail_end])
    end

    context "when resource.save fails" do
      before { allow(resource).to receive(:save).and_return(false) }

      it "still calls PaperTrail.request" do
        expect(::PaperTrail).to receive(:request).with(whodunnit: "42") do |**, &block|
          block.call
        end

        form.save
      end
    end
  end

  describe "ActionForm — around perform" do
    let(:user) { double("user", id: 7) }

    let(:form_class) do
      stub_const("TestActionForm", Class.new(WellFormed::ActionForm) do
        def perform
          # represents a transition, event dispatch, etc.
        end
      end)
    end

    subject(:form) { form_class.new(double("resource"), user) }

    it "calls PaperTrail.request with whodunnit set to user.id.to_s" do
      expect(::PaperTrail).to receive(:request).with(whodunnit: "7") do |**, &block|
        block.call
      end

      form.submit
    end

    it "wraps around perform so whodunnit is active during the action" do
      order = []

      allow(::PaperTrail).to receive(:request) do |whodunnit:, &block|
        order << :paper_trail_start
        block.call
        order << :paper_trail_end
      end

      form_class.before_perform { order << :before_perform }
      form_class.after_perform { order << :after_perform }

      form.submit

      expect(order).to eq([:paper_trail_start, :before_perform, :after_perform, :paper_trail_end])
    end
  end

  describe "global whodunnit config" do
    let(:resource) { double("resource", save: true) }
    let(:user) { double("user", id: 42, email: "alice@example.com") }

    let(:form_class) do
      stub_const("GlobalConfigForm", Class.new(WellFormed::ResourceForm) do
        attribute :title, :string

        private

        def perform = resource.save
      end)
    end

    subject(:form) { form_class.new(resource, user) }

    around do |example|
      original = WellFormed::PaperTrail.whodunnit
      example.run
    ensure
      WellFormed::PaperTrail.whodunnit = original
    end

    it "uses the global proc when no per-form macro is set" do
      WellFormed::PaperTrail.whodunnit = ->(u) { u.email }

      expect(::PaperTrail).to receive(:request).with(whodunnit: "alice@example.com") do |**, &block|
        block.call
      end

      form.save
    end

    it "per-form macro takes precedence over the global config" do
      WellFormed::PaperTrail.whodunnit = ->(u) { u.email }

      form_class.paper_trail_whodunnit { "override" }

      expect(::PaperTrail).to receive(:request).with(whodunnit: "override") do |**, &block|
        block.call
      end

      form.save
    end

    it "falls back to user.id.to_s when global config is nil" do
      WellFormed::PaperTrail.whodunnit = nil

      expect(::PaperTrail).to receive(:request).with(whodunnit: "42") do |**, &block|
        block.call
      end

      form.save
    end
  end

  describe "#paper_trail_whodunnit macro" do
    let(:resource) { double("resource", save: true) }
    let(:user) { double("user", id: 42, email: "alice@example.com") }

    context "with a custom whodunnit block" do
      let(:form_class) do
        stub_const("CustomWhodunnitForm", Class.new(WellFormed::ResourceForm) do
          attribute :title, :string
          paper_trail_whodunnit { user.email }

          private

          def perform = resource.save
        end)
      end

      subject(:form) { form_class.new(resource, user) }

      it "uses the block's return value as whodunnit" do
        expect(::PaperTrail).to receive(:request).with(whodunnit: "alice@example.com") do |**, &block|
          block.call
        end

        form.save
      end
    end

    context "when nil user" do
      let(:form_class) do
        stub_const("NilUserForm", Class.new(WellFormed::ResourceForm) do
          attribute :title, :string

          private

          def perform = resource.save
        end)
      end

      subject(:form) { form_class.new(resource, nil) }

      it "passes nil as whodunnit when user is nil" do
        expect(::PaperTrail).to receive(:request).with(whodunnit: nil) do |**, &block|
          block.call
        end

        form.save
      end
    end

    context "with a subclass overriding the whodunnit" do
      let(:parent_class) do
        stub_const("ParentForm", Class.new(WellFormed::ResourceForm) do
          attribute :title, :string
          paper_trail_whodunnit { user.email }

          private

          def perform = resource.save
        end)
      end

      let(:child_class) do
        stub_const("ChildForm", Class.new(parent_class) do
          paper_trail_whodunnit { "admin:#{user.id}" }
        end)
      end

      it "child uses its own whodunnit" do
        form = child_class.new(resource, user)

        expect(::PaperTrail).to receive(:request).with(whodunnit: "admin:42") do |**, &block|
          block.call
        end

        form.save
      end

      it "parent still uses its own whodunnit" do
        form = parent_class.new(resource, user)

        expect(::PaperTrail).to receive(:request).with(whodunnit: "alice@example.com") do |**, &block|
          block.call
        end

        form.save
      end
    end

    context "with a subclass inheriting the parent whodunnit" do
      let(:parent_class) do
        stub_const("InheritParentForm", Class.new(WellFormed::ResourceForm) do
          attribute :title, :string
          paper_trail_whodunnit { user.email }

          private

          def perform = resource.save
        end)
      end

      let(:child_class) do
        stub_const("InheritChildForm", Class.new(parent_class))
      end

      it "inherits the parent's whodunnit proc" do
        form = child_class.new(resource, user)

        expect(::PaperTrail).to receive(:request).with(whodunnit: "alice@example.com") do |**, &block|
          block.call
        end

        form.save
      end
    end
  end
end
