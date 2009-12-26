class AddStartAndEndDateToBuildsAndBuckets < ActiveRecord::Migration
  def self.up
    add_column :builds, :started_at, :datetime, :null => true
    add_column :builds, :finished_at, :datetime, :null => true
    add_column :buckets, :started_at, :datetime, :null => true
    add_column :buckets, :finished_at, :datetime, :null => true
  end

  def self.down
    remove_column :builds, :started_at
    remove_column :builds, :finished_at
    remove_column :buckets, :started_at
    remove_column :buckets, :finished_at
  end
end
