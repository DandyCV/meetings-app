# Placeholder for the meeting-attachment processing pipeline.
#
# TODO(meeting-file-processing): the real work (transcription, summarisation,
# etc.) is a separate spec. This spec (docs/specs/meeting-file-upload/spec.md)
# only establishes the enqueue seam and the processing_status lifecycle; for now
# the job simply advances the attachment out of "pending".
class ProcessMeetingAttachmentJob < ApplicationJob
  queue_as :default

  def perform(meeting_attachment)
    meeting_attachment.update!(processing_status: :processed, processed_at: Time.current)
  end
end
