module Api
  module V1
    class AttachmentsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_meeting

      # GET /api/v1/meetings/:meeting_id/attachments
      def index
        attachments = Meetings::ListMeetingAttachments.call(meeting: @meeting)
        render json: attachments.map { |attachment| attachment_json(attachment) }
      end

      # POST /api/v1/meetings/:meeting_id/attachments
      def create
        result = Meetings::AttachMeetingFile.call(
          meeting: @meeting, file: params.dig(:attachment, :file)
        )

        if result.success?
          render json: attachment_json(result.value), status: :created
        else
          render json: { errors: result.errors }, status: :unprocessable_content
        end
      end

      private

      def set_meeting
        @meeting = current_user.meetings.find_by(id: params[:meeting_id])
        render json: { error: "Not found" }, status: :not_found unless @meeting
      end

      def attachment_json(attachment)
        blob = attachment.file
        {
          id: attachment.id,
          meeting_id: attachment.meeting_id,
          filename: blob.filename.to_s,
          byte_size: blob.byte_size,
          content_type: blob.content_type,
          processing_status: attachment.processing_status,
          processed_at: attachment.processed_at&.iso8601,
          created_at: attachment.created_at.iso8601,
          download_url: "/api/v1/meetings/#{attachment.meeting_id}/attachments/#{attachment.id}/download"
        }
      end
    end
  end
end
