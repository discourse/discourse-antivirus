# frozen_string_literal: true

class TrackScannedUploadState < ActiveRecord::Migration[6.0]
  def change
    add_column :scanned_uploads, :last_scan_failed, :boolean, default: false, null: false
    add_column :scanned_uploads, :scan_result, :string
  end
end
