class AddMeetingAttachmentsCountToMeetings < ActiveRecord::Migration[8.1]
  def change
    add_column :meetings, :meeting_attachments_count, :integer, null: false, default: 0

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE meetings SET meeting_attachments_count = (
            SELECT COUNT(*) FROM meeting_attachments WHERE meeting_attachments.meeting_id = meetings.id
          )
        SQL
      end
    end
  end
end
