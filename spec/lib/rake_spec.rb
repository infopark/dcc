# encoding: utf-8
require File.dirname(__FILE__) + '/../spec_helper'

require 'dcc/rake'

module DCC

describe Rake do
  let(:rake) {Rake.new("project path", "log file")}

  describe "when performing rake" do
    before do
      allow(FileUtils).to receive(:rm_f)
      allow(FileUtils).to receive(:mkdir_p)
      allow(FileUtils).to receive(:touch)
    end

    describe "when project is bundled" do
      before do
        allow(File).to receive(:exists?).with("project path/Gemfile").and_return true
      end

      it "should execute „bundle exec rake …“" do
        expect(rake).to receive(:execute).with(['bundle', 'exec', 'rake', 'der task'], anything())
        rake.rake("der task")
      end
    end

    describe "when project is not bundled" do
      before do
        allow(File).to receive(:exists?).with("project path/Gemfile").and_return false
      end

      it "should execute „rake …“" do
        expect(rake).to receive(:execute).with(['rake', 'der task'], anything())
        rake.rake("der task")
      end
    end
  end
end

end
