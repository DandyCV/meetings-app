class CreateMeetingAttachments < ActiveRecord::Migration[8.1]
  def change
    create_table :meeting_attachments do |t|
      t.references :meeting, null: false, foreign_key: true
      t.string :processing_status, null: false, default: "pending"
      t.datetime :processed_at

      t.timestamps
    end
  end
end
