class AddErrorLogToBuckets < ActiveRecord::Migration
  def self.up
    add_column :buckets, :error_log, :text, :limit => 20.megabytes
  end

  def self.down
    remove_column :buckets, :error_log
  end
end
