class BucketStore
  attr_reader :buckets

  def initialize
    @buckets = {}
  end

  def next_bucket
    @buckets.delete_if {|k,v| !v || v.empty?}
    keys = @buckets.keys
    return if keys.empty?
    @last_key = @buckets.keys[((keys.index(@last_key) || -1) + 1) % keys.size]
    @buckets[@last_key].pop
  end

  def empty?
    @buckets.empty? || @buckets.all? {|k,v| !v || v.empty?}
  end
end
