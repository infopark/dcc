require File.dirname(__FILE__) + '/../spec_helper'
require 'lib/bucket_store'

describe BucketStore do
  before do
    @store = BucketStore.new
  end

  it "should allow to set buckets for a project" do
    @store.buckets['my_project'] = %w(my buckets)
    @store.buckets['my_project'].should == %w(my buckets)
  end

  it "should deliver buckets one by one" do
    @store.buckets['my_project'] = [1, 2, 3, 4]
    @store.next_bucket.should == 4
    @store.next_bucket.should == 3
    @store.next_bucket.should == 2
    @store.next_bucket.should == 1
  end

  it "should deliver nil when no more buckets are available" do
    @store.buckets['my_project'] = []
    @store.next_bucket.should == nil
    @store.next_bucket.should == nil
  end

  it "should deliver nil when no buckets were set" do
    @store.next_bucket.should == nil
    @store.next_bucket.should == nil
  end

  it "should remove delivered buckets from the list of buckets" do
    @store.buckets['my_project'] = [1, 2, 3, 4]
    @store.next_bucket
    @store.buckets['my_project'].should == [1, 2, 3]
  end

  it "should deliver buckets from alternating projects" do
    @store.buckets['p1'] = [11, 12]
    @store.buckets['p2'] = [21, 22]
    @store.next_bucket.should == 12
    @store.next_bucket.should == 22
    @store.next_bucket.should == 11
    @store.next_bucket.should == 21
  end

  it "should deliver buckets from alternating projects including newly added ones" do
    @store.buckets['p1'] = [11, 12, 13]
    @store.next_bucket.should == 13
    @store.buckets['p2'] = [21, 22]
    @store.next_bucket.should == 22
    @store.next_bucket.should == 12
    @store.next_bucket.should == 21
    @store.next_bucket.should == 11
  end

  it "should deliver remaining buckets from other projects when a project has no more buckets" do
    @store.buckets['p1'] = [11, 12, 13]
    @store.buckets['p2'] = [21]
    @store.buckets['p3'] = nil
    @store.next_bucket.should == 13
    @store.next_bucket.should == 21
    @store.next_bucket.should == 12
    @store.next_bucket.should == 11
  end

  it "should be empty if no buckets were set" do
    @store.should be_empty
  end

  it "should not be empty if buckets were set" do
    @store.buckets['my_project'] = [1, 2, 3, 4]
    @store.should_not be_empty
  end

  it "should be empty if no buckets are available" do
    @store.buckets['p1'] = []
    @store.buckets['p2'] = nil
    @store.buckets['p3'] = []
    @store.should be_empty
  end

  it "should not be empty if buckets are available" do
    @store.buckets['p1'] = []
    @store.buckets['p2'] = [1, 2, 3]
    @store.buckets['p3'] = []
    @store.should_not be_empty
  end
end
