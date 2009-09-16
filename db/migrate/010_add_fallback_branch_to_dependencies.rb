class AddFallbackBranchToDependencies < ActiveRecord::Migration
  def self.up
    add_column :dependencies, :fallback_branch, :string, :null => true
  end

  def self.down
    remove_column :dependencies, :fallback_branch
  end
end
