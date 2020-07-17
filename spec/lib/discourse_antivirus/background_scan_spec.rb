# frozen_string_literal: true

require 'rails_helper'

describe DiscourseAntivirus::BackgroundScan do
  fab!(:upload) { Fabricate(:image_upload) }
  let(:db_version) { 25853 }

  before do
    version_data = { antivirus: 'ClamAV 0.102.3', database: db_version, updated_at: 'Wed Jun 24 10:13:27 2020' }
    PluginStore.set(
      DiscourseAntivirus::ClamAV::PLUGIN_NAME,
      DiscourseAntivirus::ClamAV::STORE_KEY,
      [version_data]
    )
  end

  describe '#scan' do
    it 'creates a ScannedUpload' do
      scanner = build_scanner(quarantine_files: false)

      scanner.scan([upload])
      scanned_upload = ScannedUpload.find_by(upload: upload)

      expect(scanned_upload).not_to be_nil
      expect(scanned_upload.upload_id).to eq(upload.id)
      expect(scanned_upload.quarantined).to eq(false)
      expect(scanned_upload.virus_database_version_used).to eq(scanner.current_database_version)
      expect(scanned_upload.next_scan_at).to be_nil
    end

    it 'updates an existing ScannedUpload and moves it to quarantine' do
      scanner = build_scanner(quarantine_files: true)
      scanned_upload = ScannedUpload.create!(upload: upload)

      scanner.scan([upload])
      scanned_upload.reload

      expect(scanned_upload.quarantined).to eq(true)
    end

    it 'will try again in 24 hours if the file download fails' do
      socket = FakeTCPSocket.negative
      store = Discourse.store
      store.stubs(:external?).returns(true)
      store.expects(:download).with(upload).raises(OpenURI::HTTPError.new('forbidden', nil))

      antivirus = DiscourseAntivirus::ClamAV.new(store, build_fake_pool(socket: socket))
      scanner = described_class.new(antivirus)

      scanner.scan([upload])
      scanned_upload = ScannedUpload.find_by(upload: upload)

      expect(scanned_upload.scans).to eq(0)
      expect(scanned_upload.next_scan_at).to be_present
    end
  end

  describe '#scan_batch' do
    let(:scans) { 1 }

    it 'skips quarantined uploads' do
      scanned_upload = ScannedUpload.create!(upload: upload, scans: scans, quarantined: true)

      build_scanner(quarantine_files: false).scan_batch

      expect(scanned_upload.reload.scans).to eq(scans)
    end

    it 'scans uploads even if there is no scanned upload object' do
      build_scanner(quarantine_files: false).scan_batch
      scanned_upload = ScannedUpload.find_by(upload: upload)

      expect(scanned_upload).to be_present
    end

    describe 'uploads are scanned on every definition update during the first week' do
      it 'scans an upload if the last_scan_at is older than scanned_before' do
        older_version = 25852
        scanned_upload = create_scanned_upload(database_version: older_version)

        build_scanner(quarantine_files: false).scan_batch

        expect(scanned_upload.reload.scans).to eq(scans + 1)
      end

      it 'skips an upload if the last_scan_at is newer than scanned_before' do
        scanned_upload = create_scanned_upload

        build_scanner(quarantine_files: false).scan_batch

        expect(scanned_upload.reload.scans).to eq(scans)
      end
    end

    describe 'uploads are scanned every x weeks after the first week' do
      it 'ignores the database version when next_scan_at is set' do
        older_version = 25852
        scanned_upload = create_scanned_upload(database_version: older_version, next_scan_at: 3.days.from_now)

        build_scanner(quarantine_files: false).scan_batch

        expect(scanned_upload.reload.scans).to eq(scans)
      end

      it 'scans uploads' do
        scanned_upload = create_scanned_upload(next_scan_at: 1.days.ago)

        build_scanner(quarantine_files: false).scan_batch

        expect(scanned_upload.reload.scans).to eq(scans + 1)
      end
    end

    def create_scanned_upload(database_version: db_version, next_scan_at: nil)
      ScannedUpload.create!(
        upload: upload,
        virus_database_version_used: database_version,
        next_scan_at: next_scan_at,
        scans: scans
      )
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
      create_scanned_upload(updated_at: 3.days.ago)

      expect(described_class.stats[:recently_scanned]).to be_zero
    end

    it 'returns 1 recently scanned file' do
      create_scanned_upload(scans: 1, updated_at: 6.hours.ago)

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

    def create_scanned_upload(updated_at: 6.hours.ago, quarantined: false, scans: 0)
      ScannedUpload.create!(upload: upload, updated_at: updated_at, quarantined: quarantined, scans: scans)
    end
  end

  def build_fake_pool(socket:)
    OpenStruct.new(tcp_socket: socket, all_tcp_sockets: [socket])
  end

  def build_scanner(quarantine_files:)
    socket = quarantine_files ? FakeTCPSocket.positive : FakeTCPSocket.negative
    antivirus = DiscourseAntivirus::ClamAV.new(Discourse.store, build_fake_pool(socket: socket))
    described_class.new(antivirus)
  end
end
