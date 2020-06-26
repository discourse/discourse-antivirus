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

  describe '.stats' do
    it 'returns 1 scanned file' do
      create_scanned_upload(scans: 1)

      expect(described_class.stats[:scans]).to eq(1)
    end

    it 'returns the number of times each file was scanned' do
      upload_a = create_scanned_upload(scans: 3)
      upload_b = create_scanned_upload(scans: 2)

      expect(described_class.stats[:scans]).to eq(upload_a.scans + upload_b.scans)
    end

    it 'returns 0 recently scanned files' do
      create_scanned_upload(last_scanned_at: 3.days.ago)

      expect(described_class.stats[:recently_scanned]).to be_zero
    end

    it 'returns 1 recently scanned file' do
      create_scanned_upload(last_scanned_at: 6.hours.ago)

      expect(described_class.stats[:recently_scanned]).to eq(1)
    end

    it 'returns 1 quarantined files' do
      create_scanned_upload(quarantined: true)

      expect(described_class.stats[:quarantined]).to eq(1)
    end

    it 'returns 0 quarantined files' do
      create_scanned_upload(quarantined: false)

      expect(described_class.stats[:quarantined]).to be_zero
    end

    it 'returns 1 found files if a upload is moved into quarantine' do
      scanned_upload = create_scanned_upload
      scanned_upload.move_to_quarantine!("scan_message")

      expect(described_class.stats[:found]).to eq(1)
    end

    it 'returns 0 found files if there are no existing reviewables' do
      create_scanned_upload

      expect(described_class.stats[:found]).to be_zero
    end

    def create_scanned_upload(last_scanned_at: 6.hours.ago, quarantined: false, scans: 0)
      ScannedUpload.create!(upload: upload, last_scanned_at: last_scanned_at, quarantined: quarantined, scans: scans)
    end
  end

  def build_scanner(quarantine_files:)
    socket = quarantine_files ? FakeTCPSocket.positive : FakeTCPSocket.negative
    fake_antivirus = DiscourseAntivirus::ClamAV.new(Discourse.store)
    fake_antivirus.override_default_socket(socket)
    described_class.new(fake_antivirus)
  end
end
