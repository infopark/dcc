class EnlargeBucketsLogColumn < ActiveRecord::Migration
  def self.up
    change_column :buckets, :log, :text, :limit => 20.megabytes
  end

  def self.down
    change_column :buckets, :log, :text
  end
end
