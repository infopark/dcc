class RenameCommitColumn < ActiveRecord::Migration
  def self.up
    rename_column(:buckets, :commit, :commit_hash)
  end

  def self.down
    rename_column(:buckets, :commit_hash, :commit)
  end
end
