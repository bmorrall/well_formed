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

  let(:extension) { Module.new }

  it "includes a registered extension in classes that subsequently include Extensions" do
    described_class.register_extension(extension)
    base = Class.new { include WellFormed::Extensions }

    expect(base.ancestors).to include(extension)
  end

  it "retroactively includes a late-registered extension in already-registered bases" do
    base = Class.new { include WellFormed::Extensions }
    described_class.register_extension(extension)

    expect(base.ancestors).to include(extension)
  end

  it "retroactively includes in all registered bases" do
    base1 = Class.new { include WellFormed::Extensions }
    base2 = Class.new { include WellFormed::Extensions }

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
end
