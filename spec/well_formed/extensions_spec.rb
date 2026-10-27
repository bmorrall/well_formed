# frozen_string_literal: true

RSpec.describe WellFormed::Extensions do
  around do |example|
    original_extensions = described_class.instance_variable_get(:@extensions).dup
    original_bases = described_class.instance_variable_get(:@bases).dup
    example.run
  ensure
    described_class.instance_variable_set(:@extensions, original_extensions)
    described_class.instance_variable_set(:@bases, original_bases)
  end

  it "includes a registered extension in classes that subsequently include Extensions" do
    extension = Module.new
    described_class.register_extension(extension)

    base = a_base_class

    expect(base.ancestors).to include(extension)
  end

  it "retroactively includes a late-registered extension in already-registered bases" do
    extension = Module.new
    base = a_base_class

    described_class.register_extension(extension)

    expect(base.ancestors).to include(extension)
  end

  it "retroactively includes in all registered bases" do
    extension = Module.new
    base1 = a_base_class
    base2 = a_base_class

    described_class.register_extension(extension)

    expect(base1.ancestors).to include(extension)
    expect(base2.ancestors).to include(extension)
  end

  it "is included in SimpleResource" do
    expect(WellFormed::SimpleResource.ancestors).to include(described_class)
  end

  it "is included in SimpleAction" do
    expect(WellFormed::SimpleAction.ancestors).to include(described_class)
  end

  def a_base_class
    extensions = described_class
    Class.new { include extensions }
  end
end
