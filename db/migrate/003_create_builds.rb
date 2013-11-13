class CreateBuilds < ActiveRecord::Migration
  def self.up
    create_table :builds do |t|
      t.string :commit_hash, :null => false
      t.integer :build_number, :null => false
      t.belongs_to :project
    end
    add_index :builds, [:project_id, :commit_hash]
    add_index :builds, [:project_id, :commit_hash, :build_number], :unique => true
    add_index :builds, :build_number
    add_index :builds, :project_id

    Build.reset_column_information
    Bucket.all.map {|b| [b.project_id, b.commit_hash, b.build_number]}.uniq.each do |p, c, b|
      Build.create :project_id => p, :commit_hash => c, :build_number => b
    end

    add_column :buckets, :build_id, :integer, :null => false, :default => 0

    Bucket.reset_column_information
    Bucket.all.each do |bucket|
      bucket.build_id = Build.find_by_project_id_and_commit_hash_and_build_number(
          bucket.project_id, bucket.commit_hash, bucket.build_number).id
      bucket.save
    end

    add_index :buckets, [:name, :build_id], :unique => true
    add_index :buckets, :name
    add_index :buckets, :build_id
    remove_index :buckets, :column => [:project_id, :commit]
    remove_index :buckets, name: 'buckets_idx_name_pid_commit_build'
    remove_index :buckets, :column => :build_number
    remove_index :buckets, :column => :project_id
    remove_columns :buckets, :commit_hash, :project_id, :build_number
  end

  def self.down
    add_column :buckets, :commit_hash, :string, :null => false, :default => ""
    add_column :buckets, :build_number, :integer, :null => false, :default => 0
    add_column :buckets, :project_id, :integer, :null => false, :default => 0

    Bucket.reset_column_information
    Bucket.all.each do |bucket|
      build = Build.find(bucket.build_id)
      bucket.commit_hash = build.commit_hash
      bucket.build_number = build.build_number
      bucket.project_id = build.project_id
      bucket.save
    end

    add_index :buckets, [:project_id, :commit_hash],
        :name => 'index_buckets_on_project_id_and_commit'
    add_index :buckets, [:name, :project_id, :commit_hash, :build_number],
        :name => 'index_buckets_on_name_and_project_id_and_commit_and_build_number', :unique => true
    add_index :buckets, :build_number
    add_index :buckets, :project_id
    remove_index :buckets, [:name, :build_id]
    remove_index :buckets, :name
    remove_index :buckets, :build_id
    remove_column :buckets, :build_id

    drop_table :builds
  end
end

