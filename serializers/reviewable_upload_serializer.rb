# frozen_string_literal: true

require_dependency 'reviewable_serializer'

class ReviewableUploadSerializer < ReviewableSerializer
  payload_attributes :scan_message, :original_filename, :post_cooked, :uploaded_by
end
