require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::TtsAgent do
  before(:each) do
    @valid_options = Agents::TtsAgent.new.default_options
    @checker = Agents::TtsAgent.new(:name => "TtsAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
