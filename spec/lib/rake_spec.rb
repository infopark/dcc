# encoding: utf-8
require File.dirname(__FILE__) + '/../spec_helper'

require 'dcc/rake'

module DCC

describe Rake do
  let(:rake) {Rake.new("project path", "log file")}

  describe "when performing rake" do
    before do
      FileUtils.stub(:rm_f)
      FileUtils.stub(:mkdir_p)
      FileUtils.stub(:touch)
    end

    describe "when project is bundled" do
      before do
        File.stub(:exists?).with("project path/Gemfile").and_return true
      end

      it "should execute „bundle exec rake …“" do
        rake.should_receive(:execute).with(['bundle', 'exec', 'rake', 'der task'], anything())
        rake.rake("der task")
      end
    end

    describe "when project is not bundled" do
      before do
        File.stub(:exists?).with("project path/Gemfile").and_return false
      end

      it "should execute „rake …“" do
        rake.should_receive(:execute).with(['rake', 'der task'], anything())
        rake.rake("der task")
      end
    end
  end
end

end
