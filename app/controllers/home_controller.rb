class HomeController < ApplicationController
  def index
    @projects = current_user.projects.where(is_deleted: false).includes(:banner_attachment)
    @viral_projects = Project.where(viral: true, is_deleted: false)
                             .order_by_recent_journal
                             .limit(10)
                             .includes(:banner_attachment, :latest_journal_entry)
  end
end
