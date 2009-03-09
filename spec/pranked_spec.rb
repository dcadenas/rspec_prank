require 'rubygems'
require 'spec'
require 'rspec_prank'

describe "prank example" do
  700.times do
    it "should be true or false" do
      true.should == rand > 0.1
    end
  end
end
