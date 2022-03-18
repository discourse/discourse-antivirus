# frozen_string_literal: true
class UpdateReviewableUploadScoreType < ActiveRecord::Migration[6.1]
  def up
    DB.exec <<~SQL
      UPDATE reviewable_scores
      SET reviewable_score_type = 9
      WHERE reason = 'malicious_file'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
