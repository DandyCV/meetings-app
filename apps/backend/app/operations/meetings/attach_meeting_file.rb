module Meetings
  # Command: attach an uploaded file to a meeting as a MeetingAttachment.
  # On success, enqueues the processing job. Returns a Cqrs::Result.
  class AttachMeetingFile < Cqrs::Command
    def initialize(meeting:, file:)
      @meeting = meeting
      @file = file
    end

    def call
      attachment = @meeting.meeting_attachments.build
      attachment.file.attach(@file) if @file.present?

      if attachment.save
        ProcessMeetingAttachmentJob.perform_later(attachment)
        Cqrs::Result.success(attachment)
      else
        Cqrs::Result.failure(attachment.errors.full_messages)
      end
    end
  end
end
