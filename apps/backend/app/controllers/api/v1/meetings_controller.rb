module Api
  module V1
    class MeetingsController < ApplicationController
      before_action :authenticate_user!

      # GET /api/v1/meetings
      def index
        meetings = current_user.meetings.recent_first
        render json: meetings.map { |meeting| meeting_json(meeting) }
      end

      private

      def meeting_json(meeting)
        {
          id: meeting.id,
          title: meeting.title,
          description: meeting.description,
          starts_at: meeting.starts_at.iso8601
        }
      end
    end
  end
end
