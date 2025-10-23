class JournalEntriesController < ApplicationController
  before_action :set_project
  before_action :set_journal_entry, only: [ :show, :destroy, :edit, :update ]

  def show
    ahoy.track "journal_entry_view", journal_entry_id: @journal_entry.id, user_id: current_user&.id, project_id: @project.id

    if current_user.present?
      GorseSyncViewJob.perform_later(current_user.id, @journal_entry.id, Time.current, item_type: "JournalEntry")
    end

    redirect_to project_path(@journal_entry.project, return_to: params[:return_to])
  end

  def create
    not_found and return unless @project.user == current_user

    @journal_entry = @project.journal_entries.build(journal_entry_params.merge(user: current_user))

    if @journal_entry.save
      ahoy.track("journal_entry_create", project_id: @project.id, user_id: current_user.id)

      redirect_to project_path(@project), notice: "Journal entry created."
    else
      redirect_to project_path(@project), alert: "Could not create journal entry."
    end
  end

  def edit
    not_found and return unless @journal_entry.user == current_user
    not_found and return unless @project.can_edit?
  end

  def update
    not_found and return unless @journal_entry.user == current_user
    not_found and return unless @project.can_edit?

    if @journal_entry.update(journal_entry_params)
      ahoy.track("journal_entry_update", project_id: @project.id, user_id: current_user.id, journal_entry_id: @journal_entry.id)
      redirect_to project_path(@project), notice: "Journal entry updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    not_found and return unless @journal_entry.user == current_user
    not_found and return unless @project.can_edit?

    @journal_entry.destroy
    redirect_to project_path(@project), notice: "Journal entry deleted."
  end

  private

  def set_project
    @project = current_user.projects.find_by(id: params[:project_id])
    not_found unless @project
  end

  def set_journal_entry
    @journal_entry = @project.journal_entries.find_by(id: params[:id])
    not_found unless @journal_entry
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
