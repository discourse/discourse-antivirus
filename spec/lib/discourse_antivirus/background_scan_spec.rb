# frozen_string_literal: true

require "rails_helper"
require_relative "../../support/fake_pool"
require_relative "../../support/fake_tcp_socket"

describe DiscourseAntivirus::BackgroundScan do
  fab!(:upload) { Fabricate(:image_upload) }
  let(:db_version) { 25_853 }

  before do
    version_data = {
      antivirus: "ClamAV 0.102.3",
      database: db_version,
      updated_at: "Wed Jun 24 10:13:27 2020",
    }
    PluginStore.set(
      DiscourseAntivirus::ClamAv::PLUGIN_NAME,
      DiscourseAntivirus::ClamAv::STORE_KEY,
      [version_data],
    )
  end

  describe "#scan" do
    it "creates a ScannedUpload" do
      scanner = build_scanner(quarantine_files: false)
      scanned_upload = ScannedUpload.create_new!(upload)

      scanner.scan([scanned_upload])
      scanned_upload.reload

      expect(scanned_upload.quarantined).to eq(false)
      expect(scanned_upload.virus_database_version_used).to eq(db_version)
      expect(scanned_upload.next_scan_at).to be_nil
      expect(scanned_upload.scan_result).to be_present
    end

    it "updates an existing ScannedUpload and moves it to quarantine" do
      scanner = build_scanner(quarantine_files: true)
      scanned_upload = ScannedUpload.create_new!(upload)

      scanner.scan([scanned_upload])
      scanned_upload.reload

      expect(scanned_upload.quarantined).to eq(true)
    end

    it "will try again if the file download fails" do
      socket = FakeTCPSocket.negative
      store = Discourse.store
      store.stubs(:external?).returns(true)
      filesize = upload.filesize + 2.megabytes
      store
        .expects(:download)
        .with(upload, max_file_size_kb: filesize)
        .raises(OpenURI::HTTPError.new("forbidden", nil))

      antivirus = DiscourseAntivirus::ClamAv.new(store, build_fake_pool(socket))
      scanner = described_class.new(antivirus)
      scanned_upload = ScannedUpload.create_new!(upload)

      scanner.scan([scanned_upload])
      scanned_upload.reload

      expect(scanned_upload.scans).to eq(0)
      expect(scanned_upload.scan_result).to eq(DiscourseAntivirus::ClamAv::DOWNLOAD_FAILED)
      expect(scanned_upload.next_scan_at).to be_present
      expect(scanned_upload.last_scan_failed).to eq(true)
    end

    it "will try again if the store returns nil" do
      socket = FakeTCPSocket.negative
      store = Discourse.store
      store.stubs(:external?).returns(true)
      filesize = upload.filesize + 2.megabytes
      store.expects(:download).with(upload, max_file_size_kb: filesize).returns(nil)

      antivirus = DiscourseAntivirus::ClamAv.new(store, build_fake_pool(socket))
      scanner = described_class.new(antivirus)
      scanned_upload = ScannedUpload.create_new!(upload)

      scanner.scan([scanned_upload])
      scanned_upload.reload

      expect(scanned_upload.scans).to eq(0)
      expect(scanned_upload.scan_result).to eq(DiscourseAntivirus::ClamAv::DOWNLOAD_FAILED)
      expect(scanned_upload.next_scan_at).to be_present
      expect(scanned_upload.last_scan_failed).to eq(true)
    end
  end

  describe "#queue_batch" do
    it "creates a new ScannedUpload object" do
      build_scanner(quarantine_files: false).queue_batch

      scanned_upload = ScannedUpload.find_by(upload: upload)

      expect(scanned_upload.scans).to be_zero
      expect(scanned_upload.next_scan_at).to be_present
    end

    it "doesnt create a new object if there already an existing scanned upload" do
      ScannedUpload.create!(upload: upload, scans: 10)

      build_scanner(quarantine_files: false).queue_batch
      scanned_upload = ScannedUpload.find_by(upload: upload)

      expect(scanned_upload.scans).not_to be_zero
    end

    it "skips uploads when all associated posts are from a bot (like data exports)" do
      Fabricate(:post, user: Discourse.system_user, uploads: [upload])

      build_scanner(quarantine_files: false).queue_batch
      scanned_upload = ScannedUpload.find_by(upload: upload)

      expect(scanned_upload).to be_nil
    end

    it "creates the scanned upload when the upload was referenced by another user" do
      Fabricate(:post, user: Discourse.system_user, uploads: [upload])
      Fabricate(:post, uploads: [upload])

      build_scanner(quarantine_files: false).queue_batch
      scanned_upload = ScannedUpload.where(upload: upload)

      # Ensure we only created one scanned upload record
      expect(scanned_upload.count).to eq(1)
    end

    it "created the scanned upload when the upload was referenced by multiple users" do
      2.times { Fabricate(:post, uploads: [upload]) }

      build_scanner(quarantine_files: false).queue_batch
      scanned_upload = ScannedUpload.where(upload: upload)

      # Ensure we only created one scanned upload record
      expect(scanned_upload.count).to eq(1)
    end
  end

  describe "#scan_batch" do
    let(:scans) { 1 }

    it "skips quarantined uploads" do
      scanned_upload = ScannedUpload.create!(upload: upload, scans: scans, quarantined: true)

      build_scanner(quarantine_files: false).scan_batch

      expect(scanned_upload.reload.scans).to eq(scans)
    end

    describe "uploads are scanned on every definition update during the first week" do
      it "scans an upload if the last_scan_at is older than scanned_before" do
        older_version = 25_852
        scanned_upload = create_scanned_upload(database_version: older_version)

        build_scanner(quarantine_files: false).scan_batch

        expect(scanned_upload.reload.scans).to eq(scans + 1)
      end

      it "skips an upload if the last_scan_at is newer than scanned_before" do
        scanned_upload = create_scanned_upload

        build_scanner(quarantine_files: false).scan_batch

        expect(scanned_upload.reload.scans).to eq(scans)
      end
    end

    describe "uploads are scanned every x weeks after the first week" do
      it "ignores the database version when next_scan_at is set" do
        older_version = 25_852
        scanned_upload =
          create_scanned_upload(database_version: older_version, next_scan_at: 3.days.from_now)

        build_scanner(quarantine_files: false).scan_batch

        expect(scanned_upload.reload.scans).to eq(scans)
      end

      it "scans uploads" do
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
        scans: scans,
      )
    end
  end

  describe "#stats" do
    it "returns 1 scanned file" do
      create_scanned_upload(scans: 1)

      expect(get_stats(:scans)).to eq(1)
    end

    it "returns the number of times each file was scanned" do
      upload_a = create_scanned_upload(scans: 3)
      upload_b = create_scanned_upload(scans: 2)

      expect(get_stats(:scans)).to eq(upload_a.scans + upload_b.scans)
    end

    it "returns 0 recently scanned files" do
      create_scanned_upload(updated_at: 3.days.ago)

      expect(get_stats(:recently_scanned)).to be_zero
    end

    it "returns 1 recently scanned file" do
      create_scanned_upload(scans: 1, updated_at: 6.hours.ago)

      expect(get_stats(:recently_scanned)).to eq(1)
    end

    it "returns 1 quarantined files" do
      create_scanned_upload(quarantined: true)

      expect(get_stats(:quarantined)).to eq(1)
    end

    it "returns 0 quarantined files" do
      create_scanned_upload(quarantined: false)

      expect(get_stats(:quarantined)).to be_zero
    end

    it "returns 1 found files if a upload is moved into quarantine" do
      scanned_upload = create_scanned_upload(quarantined: true)
      scanned_upload.flag_upload("scan_message")

      expect(get_stats(:found)).to eq(1)
    end

    it "returns 0 found files if there are no existing reviewables" do
      create_scanned_upload

      expect(get_stats(:found)).to be_zero
    end

    def get_stats(stat)
      build_scanner.stats.dig(:background_scan_stats, stat)
    end

    def create_scanned_upload(updated_at: 6.hours.ago, quarantined: false, scans: 0)
      new_upload = Fabricate(:image_upload)
      ScannedUpload.create!(
        upload: new_upload,
        updated_at: updated_at,
        quarantined: quarantined,
        scans: scans,
      )
    end
  end

  def build_fake_pool(socket)
    FakePool.new([FakeTCPSocket.online, socket])
  end

  def build_scanner(quarantine_files: false)
    IO.stubs(:select)
    socket = quarantine_files ? FakeTCPSocket.positive : FakeTCPSocket.negative
    antivirus = DiscourseAntivirus::ClamAv.new(Discourse.store, build_fake_pool(socket))
    described_class.new(antivirus)
  end
end
