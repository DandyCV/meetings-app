module Meetings
  # Command: destroy one of a meeting's attachments (purging its blob).
  class RemoveMeetingAttachment < Cqrs::Command
    def initialize(meeting:, id:)
      @meeting = meeting
      @id = id
    end

    def call
      attachment = @meeting.meeting_attachments.find_by(id: @id)
      return Cqrs::Result.failure([ "Attachment not found" ]) unless attachment

      # Purge the attached file synchronously (disk + blob) per research §6,
      # rather than relying solely on the async after_destroy_commit hook.
      attachment.file.purge
      attachment.destroy
      Cqrs::Result.success(attachment)
    end
  end
end
