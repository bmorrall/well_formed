# frozen_string_literal: true

RSpec.describe WellFormed::WithUser do
  describe ".register_extension" do
    it "includes the registered module in any class that subsequently prepends WithUser" do
      mod = Module.new
      WellFormed::WithUser.register_extension(mod)

      klass = Class.new
      klass.prepend(WellFormed::WithUser)
      expect(klass.ancestors).to include(mod)
    ensure
      WellFormed::WithUser.instance_variable_get(:@extensions).delete(mod)
    end
  end

  describe ".included" do
    it "raises ArgumentError when included instead of prepended" do
      expect { Class.new.include(WellFormed::WithUser) }
        .to raise_error(ArgumentError, /must be prepended/)
    end
  end
end
