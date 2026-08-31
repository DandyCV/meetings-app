class AddMeetingAttachmentsCountToMeetings < ActiveRecord::Migration[8.1]
  def change
    add_column :meetings, :meeting_attachments_count, :integer, null: false, default: 0

    reversible do |dir|
      dir.up do
        Meeting.find_each { |m| Meeting.reset_counters(m.id, :meeting_attachments) }
      end
    end
  end
end
