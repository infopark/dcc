class AddWorkerUriToBucketsAndUpdateStatus < ActiveRecord::Migration
  def self.up
    add_column :buckets, :worker_uri, :string

    Bucket.update_all("status=10", "status=1")
    Bucket.update_all("status=20", "status=0")
    Bucket.update_all("status=40", "status=2")
  end

  def self.down
    Bucket.update_all("status=1", "status=10")
    Bucket.update_all("status=2", "status=40")
    Bucket.update_all("status=0", "status != 1 AND status != 2")

    remove_column :buckets, :worker_uri
  end
end
