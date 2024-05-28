# frozen_string_literal: true

class AddMaliciousFileScoreType < ActiveRecord::Migration[7.0]
  def change
    result = DB.query <<~SQL
      SELECT MAX(position) FROM flags
    SQL

    position = result.last&.max

    result = DB.query <<~SQL
      INSERT INTO flags(name, name_key, applies_to, score_type, position, created_at, updated_at)
      VALUES ('Malicious File', 'malicious_file', '{}', true, #{position.to_i + 1}, NOW(), NOW())
      RETURNING flags.id
    SQL

    new_score_id = result.last&.id

    DB.exec <<~SQL
      UPDATE reviewable_scores rs1
      SET reviewable_score_type = #{new_score_id}
      FROM reviewable_scores rs2
      LEFT JOIN reviewables ON reviewables.id = rs2.reviewable_id
      WHERE rs2.reason = 'malicious_file'
      AND reviewables.type = 'ReviewableUpload'
      AND rs1.id = rs2.id
    SQL
  end
end
