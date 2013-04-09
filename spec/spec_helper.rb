$LOAD_PATH.unshift './lib'
require 'rubygems'
require 'active_resource'
require 'dupe'

module Helpers
  def build_response(*params)
    ActiveResource::Response.new(*params)
  end
end

RSpec.configure do |config|
  config.include Helpers
end
