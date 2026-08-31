module Meetings
  # Query: a meeting's attachments, oldest first, with blobs eager-loaded.
  class ListMeetingAttachments < Cqrs::Query
    def initialize(meeting:)
      @meeting = meeting
    end

    def call
      @meeting.meeting_attachments
              .with_attached_file
              .order(created_at: :asc, id: :asc)
    end
  end
end
