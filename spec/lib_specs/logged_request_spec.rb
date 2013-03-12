require 'spec_helper'

describe Dupe::Network::Log::Request do
  describe "##new" do
    it "should set the verb, url, and response_body" do
      r = Dupe::Network::Log::Request.new :get, "/knock-knock", {"test" => "header"},"who's there?"
      r.verb.should == :get
      r.path.should == "/knock-knock"
      r.headers.should == {"test" => "header"}
      r.response_body.should == "who's there?"
    end
  end
  
  describe "#pretty_print" do
    it "should show the request type, request path, and request response" do
      r = Dupe::Network::Log::Request.new :get, "/knock-knock", {"test" => "header"}, "who's there?"
      r.pretty_print.should ==
        "Request: GET /knock-knock {\"test\"=>\"header\"}\n" +
        "Response:\n" +
        "  who's there?"
    end
  end
end
