require "spec"
require "../src/marten_tools"

describe MartenTools do
  it "has a version" do
    MartenTools::VERSION.should_not be_nil
    MartenTools::VERSION.should eq "0.1.0"
  end
end
