class AddWorkerUriToBucketsAndUpdateStatus < ActiveRecord::Migration
  def self.up
    add_column :buckets, :worker_uri, :string

    Bucket.where(status: 1).update_all("status=10")
    Bucket.where(status: 0).update_all("status=20")
    Bucket.where(status: 2).update_all("status=40")
  end

  def self.down
    Bucket.where(status: 10).update_all("status=1")
    Bucket.where(status: 40).update_all("status=2")
    Bucket.where("status != 1 AND status != 2").update_all("status=0")

    remove_column :buckets, :worker_uri
  end
end
