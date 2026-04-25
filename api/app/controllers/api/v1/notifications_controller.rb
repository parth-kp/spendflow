module Api
  module V1
    class NotificationsController < ApplicationController
      def index
        scope = policy_scope(Notification).recent
        scope = scope.unread if params[:unread] == "true"
        response.headers["X-Unread-Count"] = policy_scope(Notification).unread.count.to_s
        render json: paginate(scope).map { |n| serialize(n) }
      end

      def update
        notification = authorize Notification.find(params[:id])
        notification.read!
        render json: serialize(notification)
      end

      def read_all
        skip_authorization
        policy_scope(Notification).unread.update_all(read_at: Time.current)
        head :no_content
      end

      private

      def serialize(n)
        { id: n.id, kind: n.kind, title: n.title, body: n.body, read_at: n.read_at, created_at: n.created_at,
          subject: n.subject_type && { type: n.subject_type, id: n.subject_id } }
      end
    end
  end
end
