module Meetings
  # Command: attach an uploaded file to a meeting as a MeetingAttachment.
  # On success, enqueues the processing job. Returns a Cqrs::Result.
  class AttachMeetingFile < Cqrs::Command
    UPLOADABLE_TYPES = [ ActionDispatch::Http::UploadedFile, Rack::Test::UploadedFile ].freeze

    def initialize(meeting:, file:)
      @meeting = meeting
      @file = file
    end

    def call
      return Cqrs::Result.failure([ "File must be attached" ]) unless uploadable_file?

      attachment = @meeting.meeting_attachments.build
      attachment.file.attach(@file)

      if attachment.save
        ProcessMeetingAttachmentJob.perform_later(attachment)
        Cqrs::Result.success(attachment)
      else
        Cqrs::Result.failure(attachment.errors.full_messages)
      end
    end

    private

    def uploadable_file?
      UPLOADABLE_TYPES.any? { |type| @file.is_a?(type) }
    end
  end
end
