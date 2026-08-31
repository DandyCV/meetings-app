class MeetingAttachment < ApplicationRecord
  MAX_FILE_SIZE = 25.megabytes

  ALLOWED_CONTENT_TYPES = %w[
    application/pdf
    text/plain
    image/png
    image/jpeg
    image/gif
    image/webp
    audio/mpeg
    audio/wav
    audio/mp4
    video/mp4
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.ms-powerpoint
    application/vnd.openxmlformats-officedocument.presentationml.presentation
    application/vnd.ms-excel
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
  ].freeze

  belongs_to :meeting, counter_cache: true

  has_one_attached :file

  enum :processing_status, { pending: "pending", processed: "processed", failed: "failed" },
       default: :pending

  validate :file_presence
  validate :file_within_size_limit
  validate :file_content_type_allowed

  private

  def file_presence
    errors.add(:file, "must be attached") unless file.attached?
  end

  def file_within_size_limit
    return unless file.attached?
    return if file.byte_size.positive? && file.byte_size <= MAX_FILE_SIZE

    if file.byte_size.zero?
      errors.add(:file, "can't be empty")
    else
      errors.add(:file, "is larger than the 25 MB limit")
    end
  end

  def file_content_type_allowed
    return unless file.attached?
    return if ALLOWED_CONTENT_TYPES.include?(file.content_type)

    errors.add(:file, "type #{file.content_type} is not allowed")
  end
end
