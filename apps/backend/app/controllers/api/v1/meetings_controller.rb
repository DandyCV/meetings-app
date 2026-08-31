module Api
  module V1
    class MeetingsController < ApplicationController
      before_action :authenticate_user!

      # GET /api/v1/meetings
      def index
        meetings = current_user.meetings.recent_first
        render json: meetings.map { |meeting| meeting_json(meeting) }
      end

      # GET /api/v1/meetings/:id
      def show
        meeting = current_user.meetings.find_by(id: params[:id])
        return render json: { error: "Not found" }, status: :not_found unless meeting

        render json: meeting_json(meeting)
      end

      # POST /api/v1/meetings
      def create
        meeting = current_user.meetings.new(meeting_params)

        if meeting.save
          render json: meeting_json(meeting), status: :created
        else
          render json: { errors: meeting.errors.full_messages }, status: :unprocessable_content
        end
      end

      private

      def meeting_params
        params.require(:meeting).permit(:title, :description, :starts_at)
      end

      def meeting_json(meeting)
        {
          id: meeting.id,
          title: meeting.title,
          description: meeting.description,
          starts_at: meeting.starts_at&.iso8601,
          attachments_count: meeting.meeting_attachments_count
        }
      end
    end
  end
end
