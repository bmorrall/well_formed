# frozen_string_literal: true

RSpec.describe WellFormed::PaperTrail do
  it "has a version number" do
    expect(described_class::VERSION).not_to be_nil
  end

  describe "auto-include via WithUser" do
    it "is included automatically when WithUser is prepended" do
      form_class = a_resource_form_class

      expect(form_class.ancestors).to include(described_class)
    end
  end

  describe "ResourceForm — around save" do
    it "calls PaperTrail.request with whodunnit set to user.id.to_s" do
      stub_paper_trail_request
      form = a_resource_form_class.new(a_resource, a_user(id: 42))

      form.save

      expect(::PaperTrail).to have_received(:request).with(whodunnit: "42")
    end

    it "wraps around resource.save so whodunnit is active during the save" do
      order = []
      allow(::PaperTrail).to receive(:request) do |whodunnit:, &block|
        order << :paper_trail_start
        block.call
        order << :paper_trail_end
      end
      resource = a_resource
      allow(resource).to receive(:save) do
        order << :resource_save
        true
      end
      form = a_resource_form_class.new(resource, a_user)

      form.save

      expect(order).to eq([:paper_trail_start, :resource_save, :paper_trail_end])
    end

    it "still calls PaperTrail.request when resource.save fails" do
      stub_paper_trail_request
      form = a_resource_form_class.new(a_resource(saves: false), a_user(id: 42))

      result = form.save

      expect(result).to be(false)
      expect(::PaperTrail).to have_received(:request).with(whodunnit: "42")
    end
  end

  describe "ActionForm — around perform" do
    it "calls PaperTrail.request with whodunnit set to user.id.to_s" do
      stub_paper_trail_request
      form = an_action_form_class.new(a_resource, a_user(id: 7))

      form.submit

      expect(::PaperTrail).to have_received(:request).with(whodunnit: "7")
    end

    it "wraps around perform so whodunnit is active during the action" do
      order = []
      allow(::PaperTrail).to receive(:request) do |whodunnit:, &block|
        order << :paper_trail_start
        block.call
        order << :paper_trail_end
      end
      form_class = an_action_form_class
      form_class.before_perform { order << :before_perform }
      form_class.after_perform { order << :after_perform }
      form = form_class.new(a_resource, a_user)

      form.submit

      expect(order).to eq([:paper_trail_start, :before_perform, :after_perform, :paper_trail_end])
    end
  end

  describe "global whodunnit config" do
    around do |example|
      original = described_class.whodunnit
      example.run
    ensure
      described_class.whodunnit = original
    end

    it "uses the global proc when no per-form macro is set" do
      email = "alice@example.com"
      described_class.whodunnit = ->(u) { u.email }
      stub_paper_trail_request
      form = a_resource_form_class.new(a_resource, a_user(email:))

      form.save

      expect(::PaperTrail).to have_received(:request).with(whodunnit: email)
    end

    it "per-form macro takes precedence over the global config" do
      described_class.whodunnit = ->(u) { u.email }
      stub_paper_trail_request
      form_class = a_resource_form_class
      form_class.paper_trail_whodunnit { "override" }
      form = form_class.new(a_resource, a_user(email: "alice@example.com"))

      form.save

      expect(::PaperTrail).to have_received(:request).with(whodunnit: "override")
    end

    it "falls back to user.id.to_s when global config is nil" do
      described_class.whodunnit = nil
      stub_paper_trail_request
      form = a_resource_form_class.new(a_resource, a_user(id: 42))

      form.save

      expect(::PaperTrail).to have_received(:request).with(whodunnit: "42")
    end
  end

  describe "#paper_trail_whodunnit macro" do
    it "uses the block's return value as whodunnit" do
      email = "alice@example.com"
      stub_paper_trail_request
      form = an_email_whodunnit_form_class.new(a_resource, a_user(email:))

      form.save

      expect(::PaperTrail).to have_received(:request).with(whodunnit: email)
    end

    it "passes nil as whodunnit when user is nil" do
      stub_paper_trail_request
      form = a_resource_form_class.new(a_resource, nil)

      form.save

      expect(::PaperTrail).to have_received(:request).with(whodunnit: nil)
    end

    it "uses the child's own whodunnit when a subclass overrides it" do
      stub_paper_trail_request
      child_class = an_admin_whodunnit_form_class(an_email_whodunnit_form_class)
      form = child_class.new(a_resource, a_user(id: 42))

      form.save

      expect(::PaperTrail).to have_received(:request).with(whodunnit: "admin:42")
    end

    it "keeps the parent's own whodunnit when a subclass overrides it" do
      email = "alice@example.com"
      stub_paper_trail_request
      parent_class = an_email_whodunnit_form_class
      an_admin_whodunnit_form_class(parent_class)
      form = parent_class.new(a_resource, a_user(id: 42, email:))

      form.save

      expect(::PaperTrail).to have_received(:request).with(whodunnit: email)
    end

    it "inherits the parent's whodunnit proc when a subclass doesn't override it" do
      email = "alice@example.com"
      stub_paper_trail_request
      child_class = stub_const("InheritChildForm", Class.new(an_email_whodunnit_form_class))
      form = child_class.new(a_resource, a_user(email:))

      form.save

      expect(::PaperTrail).to have_received(:request).with(whodunnit: email)
    end
  end

  def stub_paper_trail_request
    allow(::PaperTrail).to receive(:request).and_yield
  end

  def a_resource_form_class
    stub_const("TestResourceForm", Class.new(WellFormed::ResourceForm) do
      attribute :title, :string

      private

      def perform = resource.save
    end)
  end

  def an_email_whodunnit_form_class
    stub_const("EmailWhodunnitForm", Class.new(WellFormed::ResourceForm) do
      attribute :title, :string
      paper_trail_whodunnit { user.email }

      private

      def perform = resource.save
    end)
  end

  def an_admin_whodunnit_form_class(parent_class)
    stub_const("AdminWhodunnitForm", Class.new(parent_class) do
      paper_trail_whodunnit { "admin:#{user.id}" }
    end)
  end

  def an_action_form_class
    stub_const("TestActionForm", Class.new(WellFormed::ActionForm) do
      def perform
        # represents a transition, event dispatch, etc.
      end
    end)
  end

  def a_resource(saves: true)
    Struct.new(:saves) { def save = saves }.new(saves)
  end

  def a_user(id: 1, email: "user@example.com")
    Struct.new(:id, :email, keyword_init: true).new(id:, email:)
  end
end
