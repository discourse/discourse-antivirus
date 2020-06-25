# frozen_string_literal: true

require 'rails_helper'

describe DiscourseAntivirus::BackgroundScan do
  fab!(:upload) { Fabricate(:image_upload) }

  describe '#scan' do
    it 'creates a ScannedUpload' do
      scanner = build_scanner(quarantine_files: false)

      scanner.scan([upload])
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

      scanner.scan([upload])
      scanned_upload.reload

      expect(scanned_upload.quarantined).to eq(true)
      expect(scanned_upload.last_scanned_at).not_to eq_time(last_scan)
    end
  end

  describe '#scan_batch' do
    let(:last_scan) { 6.hours.ago }

    it 'scans an upload if the last_scan_at is older than scanned_before' do
      scanned_upload = ScannedUpload.create!(upload: upload, last_scanned_at: last_scan)

      build_scanner(quarantine_files: false).scan_batch(scanned_before: 1.hours.ago)

      expect(scanned_upload.reload.last_scanned_at).not_to eq_time(last_scan)
    end

    it 'skips an upload if the last_scan_at is newer than scanned_before' do
      scanned_upload = ScannedUpload.create!(upload: upload, last_scanned_at: last_scan)

      build_scanner(quarantine_files: false).scan_batch(scanned_before: 7.hours.ago)

      expect(scanned_upload.reload.last_scanned_at).to eq_time(last_scan)
    end

    it 'scans uploads even if there is no scanned upload object' do
      build_scanner(quarantine_files: false).scan_batch(scanned_before: 7.hours.ago)
      scanned_upload = ScannedUpload.find_by(upload: upload)

      expect(scanned_upload).to be_present
    end

    it 'skips quarantined uploads' do
      scanned_upload = ScannedUpload.create!(upload: upload, last_scanned_at: last_scan, quarantined: true)

      build_scanner(quarantine_files: false).scan_batch(scanned_before: 1.hours.ago)

      expect(scanned_upload.reload.last_scanned_at).to eq_time(last_scan)
    end
  end

  def build_scanner(quarantine_files:)
    socket = quarantine_files ? FakeTCPSocket.positive : FakeTCPSocket.negative
    fake_antivirus = DiscourseAntivirus::ClamAV.new(Discourse.store)
    fake_antivirus.override_default_socket(socket)
    described_class.new(fake_antivirus)
  end
end
