# frozen_string_literal: true

class AddUniqueIndexToScannedUploads < ActiveRecord::Migration[6.0]
  def change
    add_index :scanned_uploads, :upload_id, unique: true
  end
end
