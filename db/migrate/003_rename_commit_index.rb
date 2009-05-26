class RenameCommitIndex < ActiveRecord::Migration
  def self.up
    remove_index :buckets, :column => [:project_id, :commit]
    remove_index :buckets, :column => [:name, :project_id, :commit, :build_number]
    add_index :buckets, [:project_id, :commit_hash]
    add_index :buckets, [:name, :project_id, :commit_hash, :build_number], :unique => true
  end

  def self.down
    remove_index :buckets, :column => [:project_id, :commit_hash]
    remove_index :buckets, :column => [:name, :project_id, :commit_hash, :build_number]
    add_index :buckets, [:project_id, :commit_hash],
        :name => 'index_buckets_on_project_id_and_commit'
    add_index :buckets, [:name, :project_id, :commit_hash, :build_number],
        :name => 'index_buckets_on_name_and_project_id_and_commit_and_build_number', :unique => true
  end
end

