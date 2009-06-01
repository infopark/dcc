class EnlargeLogsLogColumn < ActiveRecord::Migration
  def self.up
    change_column :logs, :log, :text, :limit => 20.megabytes
  end

  def self.down
    change_column :logs, :log, :text
  end
end
