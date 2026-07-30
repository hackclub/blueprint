# Refuse new Active Storage direct uploads once the program has ended.
#
# This is the endpoint every upload form in the app posts to (all of them use
# `direct_upload: true`), so blocking it here covers journal images, project
# banners, demo pictures, and cart screenshots in one place. Admins keep upload
# access for shop items and imports.
#
# ActiveStorage::DirectUploadsController descends from ActiveStorage::BaseController,
# which does not include the app's Authentication concern, so the acting user is
# read straight off the session the same way Authentication#set_current_user does.
Rails.application.config.to_prepare do
  ActiveStorage::DirectUploadsController.class_eval do
    before_action :reject_when_program_ended

    private

    def reject_when_program_ended
      return unless ProgramStatus.ended?
      return if acting_admin?

      render json: { error: ProgramStatus::MESSAGE }, status: :forbidden
    end

    # session[:original_id] is set while an admin is impersonating someone;
    # either identity being an admin is enough to allow the upload.
    def acting_admin?
      ids = [ session[:user_id], session[:original_id] ].compact
      return false if ids.empty?

      User.where(id: ids, admin: true).exists?
    end
  end
end
