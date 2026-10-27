# frozen_string_literal: true

RSpec.describe WellFormed::WithUser do
  describe ".register_extension" do
    it "includes the registered module in any class that subsequently prepends WithUser" do
      extension = Module.new
      described_class.register_extension(extension)
      klass = Class.new

      klass.prepend(described_class)

      expect(klass.ancestors).to include(extension)
    ensure
      described_class.instance_variable_get(:@extensions).delete(extension)
    end
  end

  describe ".included" do
    it "raises ArgumentError when included instead of prepended" do
      klass = Class.new

      expect { klass.include(described_class) }
        .to raise_error(ArgumentError, /must be prepended/)
    end
  end
end
