class RenameCommitColumn < ActiveRecord::Migration
  def self.up
    remove_index :buckets, [:name, :project_id, :commit, :build_number]
    rename_column(:buckets, :commit, :commit_hash)
    add_index :buckets, [:name, :project_id, :commit_hash, :build_number],
        :unique => true, :name => 'buckets_idx_name_pid_commit_build'
  end

  def self.down
    remove_index :buckets, [:name, :project_id, :commit_hash, :build_number]
    rename_column(:buckets, :commit_hash, :commit)
    add_index :buckets, [:name, :project_id, :commit, :build_number], :unique => true
  end
end
