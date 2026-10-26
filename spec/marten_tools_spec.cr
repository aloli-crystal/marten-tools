require "spec"
require "yaml"
require "../src/marten_tools"

describe MartenTools do
  it "has a version" do
    MartenTools::VERSION.should_not be_nil
    yml = YAML.parse(File.read(File.join(__DIR__, "..", "shard.yml")))
    MartenTools::VERSION.should eq(yml["version"].as_s)
  end
end
