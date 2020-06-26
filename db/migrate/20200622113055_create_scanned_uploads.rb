# frozen_string_literal: true

class CreateScannedUploads < ActiveRecord::Migration[6.0]
  def change
    create_table :scanned_uploads do |t|
      t.integer :upload_id
      t.datetime :last_scanned_at
      t.boolean :quarantined, null: false, default: false
      t.integer :scans, null: false, default: 0
      t.timestamps
    end
  end
end
