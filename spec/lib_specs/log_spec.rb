require 'spec_helper'

describe Dupe::Network::Log do
  before do
    Dupe.reset
  end
  
  describe "##new" do
    it "should initialize the request entries to an empty array" do
      log = Dupe::Network::Log.new
      log.requests.should == []
    end
  end
  
  describe "#add_request" do
    before do
      @log = Dupe::Network::Log.new
    end
    
    it "should require a valid HTTP verb" do
      expect { 
        @log.add_request :invalid_http_verb, '/some_url', {}
      }.to raise_error(Dupe::Network::UnknownRestVerbError)
      expect {
        Dupe::Network::VERBS.each do |verb|
          @log.add_request verb, '/some_url', {}
        end
      }.to_not raise_error
    end
    
    it "should require a url and headers" do
      expect {
        @log.add_request :get
      }.to raise_error(ArgumentError)
      expect {
        @log.add_request :get, "/path"
      }.to raise_error(ArgumentError)
      expect {
        @log.add_request :get, '/a_url', {}
      }.to_not raise_error
    end
    
    it "should add a Dupe::Network::Log::MockedRequest to requests" do
      @log.requests.should be_empty
      path = '/translate?q=hola&from=spanish&to=english'
      response_body = 'hello'
      headers = {"test" => "header"}
      @log.add_request :get, path, headers, response_body
      @log.requests.should_not be_empty
      @log.requests.length.should == 1
      logged_request = @log.requests.first
      logged_request.should be_kind_of(Dupe::Network::Log::Request)
      logged_request.verb.should == :get
      logged_request.path.should == path
      logged_request.headers.should == headers
      logged_request.response_body.should == response_body
    end
  end
  
  describe "#pretty_print" do
    before do
      @log = Dupe::Network::Log.new
      @log.add_request :get, '/knock-knock', {"test" => "headers"}, "who's there?"
    end
    it "should return a formatted list of mocked requests" do
      @log.pretty_print.should == 
       "Logged Requests:\n" +
       "  Request: GET /knock-knock {\"test\"=>\"headers\"}\n" +
       "  Response:\n" +
       "    who's there?\n\n"
    end
  end
  
  describe "#reset" do
    it "should clear out all logged requests" do
      @log = Dupe::Network::Log.new
      @log.add_request :get, '/knock-knock', "who's there?"
      @log.requests.should_not be_empty
      @log.reset
      @log.requests.should be_empty
    end
  end
end
