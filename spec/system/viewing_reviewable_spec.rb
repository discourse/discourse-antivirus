# frozen_string_literal: true

describe "Viewing reviewable upload" do
  fab!(:admin)
  fab!(:group)
  fab!(:upload)
  fab!(:reviewable) do
    ReviewableUpload
      .needs_review!(
        target: upload,
        created_by: Discourse.system_user,
        payload: {
          uploaded_to: [upload.post_ids],
          scan_message: "Infected with EICAR-Test-File",
        },
      )
      .tap { |r| r.update!(target_created_by: upload.user) }
  end
  let(:refreshed_review_page) { PageObjects::Pages::RefreshedReview.new }
  let(:confirmation_dialog) { PageObjects::Components::Dialog.new }

  before do
    SiteSetting.discourse_antivirus_enabled = true
    SiteSetting.reviewable_ui_refresh = group.name
    group.add(admin)
    sign_in(admin)
  end

  it "Allows to delete file" do
    refreshed_review_page.visit_reviewable(reviewable)

    expect(page).to have_text("Infected with EICAR-Test-File")
    expect(page).not_to have_text(I18n.t("js.review.statuses.deleted.title"))

    refreshed_review_page.select_bundled_action(reviewable, "upload-remove_file")

    expect(page).to have_text(I18n.t("js.review.statuses.deleted.title"))
  end

  it "Allows to delete file and posts" do
    refreshed_review_page.visit_reviewable(reviewable)

    expect(page).to have_text("Infected with EICAR-Test-File")
    expect(page).not_to have_text(I18n.t("js.review.statuses.deleted.title"))

    refreshed_review_page.select_bundled_action(reviewable, "upload-remove_file_and_delete_posts")

    expect(page).to have_text(I18n.t("js.review.statuses.deleted.title"))
  end

  it "Allows to delete file and user" do
    refreshed_review_page.visit_reviewable(reviewable)

    expect(page).to have_text("Infected with EICAR-Test-File")
    expect(page).not_to have_text(I18n.t("js.review.statuses.deleted.title"))

    refreshed_review_page.select_bundled_action(reviewable, "upload-remove_file_and_delete_user")
    expect(confirmation_dialog).to be_open
    confirmation_dialog.click_yes

    expect(page).to have_text(I18n.t("js.review.statuses.deleted.title"))
  end
end
