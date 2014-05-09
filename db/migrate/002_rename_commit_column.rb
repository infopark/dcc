class RenameCommitColumn < ActiveRecord::Migration
  def self.up
    remove_index :buckets, :column => [:project_id, :commit]
    remove_index :buckets, name: "index_buckets_n_pi_c_bn"
    rename_column(:buckets, :commit, :commit_hash)
    add_index :buckets, [:name, :project_id, :commit_hash, :build_number],
        :unique => true, :name => 'buckets_idx_name_pid_commit_build'
    add_index :buckets, [:project_id, :commit_hash]
  end

  def self.down
    remove_index :buckets, :column => [:project_id, :commit_hash]
    remove_index :buckets, name: 'buckets_idx_name_pid_commit_build'
    rename_column(:buckets, :commit_hash, :commit)
    add_index :buckets, [:name, :project_id, :commit, :build_number], :unique => true,
        :name => "index_buckets_n_pi_c_bn"
    add_index :buckets, [:project_id, :commit]
  end
end
