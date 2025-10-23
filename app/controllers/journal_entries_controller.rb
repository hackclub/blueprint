class JournalEntriesController < ApplicationController
  before_action :set_project
  before_action :set_journal_entry, only: [ :show, :destroy, :edit, :update ]
  before_action :require_project_owner!, only: [ :create ]
  before_action :require_owner_or_author!, only: [ :edit, :update, :destroy ]

  def show
    ahoy.track "journal_entry_view", journal_entry_id: @journal_entry.id, user_id: current_user&.id, project_id: @project.id

    if current_user.present?
      GorseSyncViewJob.perform_later(current_user.id, @journal_entry.id, Time.current, item_type: "JournalEntry")
    end

    redirect_to project_path(@journal_entry.project, return_to: params[:return_to])
  end

  def create
    @journal_entry = @project.journal_entries.build(journal_entry_params.merge(user: current_user))

    if @journal_entry.save
      ahoy.track("journal_entry_create", project_id: @project.id, user_id: current_user.id)

      redirect_to project_path(@project), notice: "Journal entry created."
    else
      redirect_to project_path(@project), alert: "Could not create journal entry."
    end
  end

  def edit
  end

  def update
    if @journal_entry.update(journal_entry_params)
      ahoy.track("journal_entry_update", project_id: @project.id, user_id: current_user.id, journal_entry_id: @journal_entry.id)
      redirect_to project_path(@project), notice: "Journal entry updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @journal_entry.destroy
    redirect_to project_path(@project), notice: "Journal entry deleted."
  end

  private

  def set_project
    @project = Project.find_by(id: params[:project_id])
    not_found unless @project
  end

  def set_journal_entry
    @journal_entry = @project.journal_entries.find_by(id: params[:id])
    not_found unless @journal_entry
  end

  def require_project_owner!
    uid = current_user&.id
    not_found and return unless uid && @project.user_id == uid
  end

  def require_owner_or_author!
    uid = current_user&.id
    not_found and return unless uid && (@project.user_id == uid || @journal_entry.user_id == uid)
  end

  def journal_entry_params
    permitted = params.require(:journal_entry).permit(:content, :summary, :duration_hours)

    if permitted[:duration_hours].present?
      raw = permitted.delete(:duration_hours).to_s
      hours = Float(raw) rescue nil
      if hours && hours.positive?
        hours_1dp = (hours * 10).round / 10.0
        permitted[:duration_seconds] = (hours_1dp * 3600).round
      end
    end

    permitted
  end
end
