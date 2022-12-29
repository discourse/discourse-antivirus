# frozen_string_literal: true

require_dependency "reviewable_serializer"

class ReviewableUploadSerializer < ReviewableSerializer
  payload_attributes :scan_message, :original_filename, :post_raw, :uploaded_by
end
