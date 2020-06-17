# frozen_string_literal: true

require 'rails_helper'

describe DiscourseAntivirus::BackgroundScan do
  describe "#scan" do
    context 'with local uploads' do
      fab!(:upload) { Fabricate(:image_upload) }

      it 'creates a ScannedUpload' do
        scanner = build_scanner(quarantine_files: false)

        scanner.scan(upload)
        scanned_upload = ScannedUpload.find_by(upload: upload)

        expect(scanned_upload).not_to be_nil
        expect(scanned_upload.upload_id).to eq(upload.id)
        expect(scanned_upload.quarantined).to eq(false)
        expect(scanned_upload.last_scanned_at).not_to be_nil
      end

      it 'updates an existing ScannedUpload and moves it to quarantine' do
        scanner = build_scanner(quarantine_files: true)
        last_scan = 6.hours.ago
        scanned_upload = ScannedUpload.create!(upload: upload, last_scanned_at: last_scan)

        scanner.scan(upload)
        scanned_upload.reload

        expect(scanned_upload.quarantined).to eq(true)
        expect(scanned_upload.last_scanned_at).not_to eq_time(last_scan)
      end
    end
  end

  def build_scanner(quarantine_files:)
    socket = quarantine_files ? FakeTCPSocket.positive : FakeTCPSocket.negative
    fake_antivirus = DiscourseAntivirus::ClamAV.new(socket, Discourse.store)
    described_class.new(fake_antivirus)
  end
end
