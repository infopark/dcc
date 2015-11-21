# encoding: utf-8
require File.dirname(__FILE__) + '/../spec_helper'
require 'dcc/bucket_store'

module DCC

describe BucketStore do
  before do
    @store = BucketStore.new
  end

  it "should allow to set buckets for a project" do
    @store.set_buckets 'my_project', %w(my buckets)
  end

  it "should deliver buckets one by one in the order specified" do
    @store.set_buckets 'my_project', [1, 2, 3, 4]
    expect(@store.next_bucket('1')).to eq(1)
    expect(@store.next_bucket('1')).to eq(2)
    expect(@store.next_bucket('1')).to eq(3)
    expect(@store.next_bucket('1')).to eq(4)
  end

  it "should deliver nil when no more buckets are available" do
    @store.set_buckets 'my_project', []
    expect(@store.next_bucket('1')).to eq(nil)
    expect(@store.next_bucket('1')).to eq(nil)
  end

  it "should deliver nil when no buckets were set" do
    expect(@store.next_bucket('1')).to eq(nil)
    expect(@store.next_bucket('1')).to eq(nil)
  end

  it "should be empty if no buckets were set" do
    expect(@store).to be_empty
  end

  it "should not be empty if buckets were set" do
    @store.set_buckets 'my_project', [1, 2, 3, 4]
    expect(@store).not_to be_empty
  end

  it "should be empty if no buckets are available" do
    @store.set_buckets 'p1', []
    @store.set_buckets 'p2', nil
    @store.set_buckets 'p3', []
    expect(@store).to be_empty
  end

  it "should be empty if all buckets are consumed" do
    @store.set_buckets 'my_project', [1, 2, 3, 4]
    @store.next_bucket('1')
    @store.next_bucket('1')
    @store.next_bucket('1')
    @store.next_bucket('1')
    expect(@store).to be_empty
  end

  it "should not be empty if buckets are available" do
    @store.set_buckets 'p1', []
    @store.set_buckets 'p2', [1, 2, 3]
    @store.set_buckets 'p3', []
    expect(@store).not_to be_empty
  end

  describe "when delivering emptiness for a specific project" do
    before do
      @store.set_buckets 'p1', []
      @store.set_buckets 'p2', [1, 2, 3]
      @store.set_buckets 'p3', nil
    end

    it "should return true if project was never initialized" do
      expect(@store).to be_empty('p4')
    end

    it "should return true if project has no buckets" do
      expect(@store).to be_empty('p1')
      expect(@store).to be_empty('p3')
    end

    it "should return false if project has buckets" do
      expect(@store).not_to be_empty('p2')
    end
  end

  describe "when delivering buckets for multiple projects" do
    it "should deliver buckets from alternating projects" do
      @store.set_buckets 'p1', [11, 12]
      @store.set_buckets 'p2', [21, 22]
      buckets = [@store.next_bucket('1'), @store.next_bucket('2')]
      expect(buckets).to include(11)
      expect(buckets).to include(21)
      buckets = [@store.next_bucket('3'), @store.next_bucket('4')]
      expect(buckets).to include(12)
      expect(buckets).to include(22)
    end

    it "should deliver buckets from alternating projects including newly added ones" do
      @store.set_buckets 'p1', [11, 12, 13]
      expect(@store.next_bucket('1')).to eq(11)
      @store.set_buckets 'p2', [21, 22]
      expect(@store.next_bucket('2')).to eq(21)
      buckets = [@store.next_bucket('3'), @store.next_bucket('4')]
      expect(buckets).to include(12)
      expect(buckets).to include(22)
      expect(@store.next_bucket('5')).to eq(13)
    end

    it "should deliver remaining buckets from other projects when a project has no more buckets" do
      @store.set_buckets 'p1', [11, 12, 13]
      @store.set_buckets 'p2', [21]
      @store.set_buckets 'p3', nil
      buckets = [@store.next_bucket('1'), @store.next_bucket('2')]
      expect(buckets).to include(11)
      expect(buckets).to include(21)
      expect(@store.next_bucket('3')).to eq(12)
      expect(@store.next_bucket('4')).to eq(13)
    end

    it "should try to give all projects the same amount of workers" do
      @store.set_buckets 'p1', [10, 11, 12, 13, 14, 15, 16]
      @store.set_buckets 'p2', [20, 21, 22, 23, 24, 25, 26]
      buckets = [@store.next_bucket('1'), @store.next_bucket('2')]
      expect(buckets).to include(10)
      expect(buckets).to include(20)
      buckets = [@store.next_bucket('3'), @store.next_bucket('4')]
      expect(buckets).to include(11)
      expect(buckets).to include(21)
      buckets = [@store.next_bucket('5'), @store.next_bucket('6')]
      expect(buckets).to include(12)
      expect(buckets).to include(22)

      # Zunächst bekommt p3 alle worker, um die Balance herzustellen
      @store.set_buckets 'p3', [30, 31, 32, 33, 34, 35, 36]
      expect(@store.next_bucket('7')).to eq(30)
      expect(@store.next_bucket('8')).to eq(31)
      expect(@store.next_bucket('9')).to eq(32)

      # Jetzt bekommt immer ein Projekt aus der Menge derer, die am wenigsten worker haben
      buckets = [
        @store.next_bucket('10'),
        @store.next_bucket('11'),
        @store.next_bucket('12')
      ]
      expect(buckets).to be_include(13)
      expect(buckets).to be_include(23)
      expect(buckets).to be_include(33)

      # Freigewordene Worker gehen im Balancefall an den hergebenden …
      expect(@store.next_bucket('12')).to eq(buckets[2] + 1)
      expect(@store.next_bucket('10')).to eq(buckets[0] + 1)
      expect(@store.next_bucket('11')).to eq(buckets[1] + 1)

      # … ansonsten an einen aus der Menge derer, die am wenigsten worker haben
      @store.set_buckets 'p4', [41, 42, 43, 44, 45, 46]
      expect(@store.next_bucket('10')).to eq(41)
      expect(@store.next_bucket('11')).to eq(42)
      expect(@store.next_bucket('12')).to eq(43)
      expect(@store.next_bucket('10')).to eq(44)

      # wird ein Projekt reinitialisiert, fängt es wieder bei 0 an
      @store.set_buckets 'p1', [1, 2, 3, 4, 5, 6]
      expect(@store.next_bucket('a')).to eq(1)
      expect(@store.next_bucket('b')).to eq(2)
      expect(@store.next_bucket('c')).to eq(3)
    end
  end
end

end
