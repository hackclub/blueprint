class ProjectsController < ApplicationController
  allow_unauthenticated_access only: %i[explore show]

  def index
    @projects = current_user.projects.where(is_deleted: false)
      .order_by_recent_journal
      .includes(:banner_attachment)
  end

  def explore
    params[:sort] ||= "top"
    params[:type] ||= "projects"

    # Ensure valid page number
    if params[:page].present?
      params[:page] = [ params[:page].to_i, 1 ].max.to_s
    end

    if params[:type] == "journals"
      if params[:sort] == "new"
        @pagy, @journal_entries = pagy(JournalEntry.includes(project: :user).where(projects: { is_deleted: false }).references(:projects).order(created_at: :desc), items: 20)
      elsif params[:sort] == "you"
        if current_user && Flipper.enabled?(:gorse_recommendations, current_user)
          page = params[:page].present? ? params[:page].to_i : 1
          entry_ids = GorseService.get_user_recommendation(current_user.id, page, 20, type: :entry)

          # Redirect new users with no recommendations to top
          if page == 1 && entry_ids.empty?
            redirect_to explore_path(sort: "top", page: params[:page], type: params[:type]) and return
          end

          # Calculate count: if empty, we've reached the end
          count = entry_ids.empty? ? (page - 1) * 20 : page * 20 + 1

          # Create manual pagy object for navigation
          @pagy = Pagy.new(count: count, page: page, items: 20, overflow: :last_page)

          # Load entries maintaining Gorse order
          if entry_ids.any?
            order_clause = ApplicationRecord.sanitize_sql_array([ "array_position(ARRAY[?], journal_entries.id::int)", entry_ids.map(&:to_i) ])
            @journal_entries = JournalEntry.where(id: entry_ids).includes(project: :user).order(Arel.sql(order_clause))
          else
            @journal_entries = []
          end
        else
          all_entries = current_user.recommended_journal_entries if current_user.present?
          if all_entries.nil? || all_entries.count < 5
            redirect_to explore_path(sort: "top", page: params[:page], type: params[:type]) and return
          end
          entry_ids = all_entries.pluck(:id)
          @pagy, paginated_ids = pagy_array(entry_ids, items: 20)
          order_clause = ApplicationRecord.sanitize_sql_array([ "array_position(ARRAY[?], journal_entries.id::int)", paginated_ids.map(&:to_i) ])
          @journal_entries = JournalEntry.where(id: paginated_ids).includes(project: :user).order(Arel.sql(order_clause))
        end
      elsif params[:sort] == "top"
        if Flipper.enabled?(:gorse_journal_recommendations, current_user)
          page = params[:page].present? ? params[:page].to_i : 1
          entry_ids = GorseService.get_popular_items(page, 20, type: :entry)

          # Calculate count: if empty, we've reached the end
          count = entry_ids.empty? ? (page - 1) * 20 : page * 20 + 1

          # Create manual pagy object for navigation
          @pagy = Pagy.new(count: count, page: page, items: 20, overflow: :last_page)

          # Load entries maintaining Gorse order
          if entry_ids.any?
            order_clause = ApplicationRecord.sanitize_sql_array([ "array_position(ARRAY[?], journal_entries.id::int)", entry_ids.map(&:to_i) ])
            @journal_entries = JournalEntry.where(id: entry_ids).includes(project: :user).order(Arel.sql(order_clause))
          else
            @journal_entries = []
          end
        else
          top_entries = StoredRecommendation.find_by(key: "top_journal_entries")&.data
          if top_entries.present?
            entry_ids = top_entries.map { |item| item["item_id"] }
            order_clause = ApplicationRecord.sanitize_sql_array([ "array_position(ARRAY[?], journal_entries.id::int)", entry_ids.map(&:to_i) ])
            all_entries = JournalEntry.where(id: entry_ids).includes(project: :user).where(projects: { is_deleted: false }).references(:projects).order(Arel.sql(order_clause))
            @pagy, @journal_entries = pagy_array(all_entries.to_a, items: 20)
          end
        end
      else
        redirect_to explore_path and return
      end
    elsif params[:type] == "projects"
      if params[:sort] == "new"
        @pagy, @projects = pagy(Project.where(is_deleted: false).includes(:banner_attachment, :latest_journal_entry).order(created_at: :desc), limit: 21)
        preload_project_metrics(@projects)
      elsif params[:sort] == "you"
        if current_user && Flipper.enabled?(:gorse_recommendations, current_user)
          page = params[:page].present? ? params[:page].to_i : 1
          project_ids = GorseService.get_user_recommendation(current_user.id, page, 21, type: :project)

          # Redirect new users with no recommendations to top
          if page == 1 && project_ids.empty?
            redirect_to explore_path(sort: "top", page: params[:page], type: params[:type]) and return
          end

          # Calculate count: if empty, we've reached the end
          count = project_ids.empty? ? (page - 1) * 21 : page * 21 + 1

          # Create manual pagy object for navigation
          @pagy = Pagy.new(count: count, page: page, items: 21, overflow: :last_page)

          # Load projects maintaining Gorse order
          if project_ids.any?
            order_clause = ApplicationRecord.sanitize_sql_array([ "array_position(ARRAY[?], projects.id::int)", project_ids.map(&:to_i) ])
            @projects = Project.where(id: project_ids).includes(:banner_attachment, :latest_journal_entry).order(Arel.sql(order_clause))
            preload_project_metrics(@projects)
          else
            @projects = []
          end
        else
          all_projects = current_user.recommended_projects.where(is_deleted: false) if current_user.present?
          if all_projects.nil? || all_projects.count < 5
            redirect_to explore_path(type: "projects", sort: "top", page: params[:page]) and return
          end
          project_ids = all_projects.pluck(:id)
          @pagy, paginated_ids = pagy_array(project_ids, limit: 21)
          order_clause = ApplicationRecord.sanitize_sql_array([ "array_position(ARRAY[?], projects.id::int)", paginated_ids.map(&:to_i) ])
          @projects = Project.where(id: paginated_ids).includes(:banner_attachment, :latest_journal_entry).order(Arel.sql(order_clause))
          preload_project_metrics(@projects)
        end
      elsif params[:sort] == "top"
        all_projects = Project.where(is_deleted: false).includes(:banner_attachment, :latest_journal_entry).order(views_count: :desc)
        @pagy, @projects = pagy(all_projects, limit: 21)
        preload_project_metrics(@projects)
      else
        redirect_to explore_path(type: "projects") and return
      end
    else
      redirect_to explore_path and return
    end

    render "_explore_entries" and return if params[:type] == "journals" && params[:page]
    render "_explore_projects" and return if params[:type] == "projects" && params[:page]
    render "explore", layout: "application"
  end

  def show
    @project = Project.includes(:user, :banner_attachment).find_by(id: params[:id], is_deleted: false)
    not_found and return unless @project

    ahoy.track("project_view", project_id: @project.id, user_id: current_user&.id)

    if current_user.present?
      GorseSyncViewJob.perform_later(current_user.id, @project.id, Time.current)

      begin
        UniqueProjectViewTracker.record(project_id: @project.id, user_id: current_user.id)
      rescue => e
        Rails.logger.error("UniqueProjectViewTracker failed: #{e.class}: #{e.message}")
        Sentry.capture_exception(e) if defined?(Sentry)
      end
    end
  end

  def ship
    @project = current_user.projects.find_by(id: params[:id], is_deleted: false)
    not_found and return unless @project

    if !@project.can_ship?
      redirect_to project_path(@project), alert: "Project cannot be shipped."
      return
    end

    repo_linked = @project.repo_link.present?
    desc_ok = true # @project.description.to_s.strip.length >= 50
    journal_ok = true # @project.journal_entries.count >= 3
    banner_ok = true # @project.banner.attached?

    @checks = [
      { msg: "GitHub repo linked", met: repo_linked },
      { key: "bom", msg: "Bill of materials (bom.csv) present", met: nil },
      { key: "readme", msg: "README.md present", met: nil },
      { msg: "Description is at least 50 characters on Blueprint", met: desc_ok },
      { msg: "Project has 3 journal entries", met: journal_ok },
      { msg: "Banner image uploaded", met: banner_ok }
    ]

    @base_ok = repo_linked && desc_ok && journal_ok && banner_ok
  end

  def follow
    @project = Project.where.not(user_id: current_user.id).find_by(id: params[:id], is_deleted: false)
    not_found unless @project

    current_user.follow_project!(@project)
    redirect_to project_path(@project), notice: "Followed #{@project.title}."
  end

  def unfollow
    @project = Project.where.not(user_id: current_user.id).find_by(id: params[:id], is_deleted: false)
    not_found unless @project

    current_user.unfollow_project!(@project)
    redirect_to project_path(@project), notice: "Unfollowed #{@project.title}."
  end

  def new
    @project = current_user.projects.build
  end

  def create
    @project = current_user.projects.build(project_params)
    if @project.save
      ahoy.track("project_create", project_id: @project.id, user_id: current_user&.id)
      redirect_to projects_path, notice: "Project created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @project = current_user.projects.find_by(id: params[:id], is_deleted: false)
    not_found unless @project
    not_found unless @project.can_edit?
  end

  def update
    @project = current_user.projects.find_by(id: params[:id], is_deleted: false)
    not_found and return unless @project
    not_found and return unless @project.can_edit?

    has_ship = params.dig(:project, :ship).present?
    params[:project].delete(:ship) if has_ship

    if params.dig(:project, :ysws) == "none"
      params[:project][:ysws] = nil
    elsif params.dig(:project, :ysws) == "other" && params.dig(:project, :ysws_other).present?
      params[:project][:ysws] = params[:project][:ysws_other]
    end
    params[:project].delete(:ysws_other)

    # Compute print_legion from radio inputs
    if params.dig(:project, :has_3d_print).present? && params.dig(:project, :needs_3d_print_help).present?
      has_3d = params[:project][:has_3d_print] == "yes"
      needs_help = params[:project][:needs_3d_print_help] == "yes"
      params[:project][:print_legion] = (has_3d && needs_help)
    end

    # Validate cart_screenshots if needed
    if has_ship && @project.needs_funding? && !@project.cart_screenshots.attached? && Array(params.dig(:project, :cart_screenshots)).reject(&:blank?).empty?
      @project.errors.add(:cart_screenshots, "are required when requesting funding")
      render :ship, status: :unprocessable_entity and return
    end

    if @project.update(project_params)
      if has_ship
        ahoy.track("project_ship", project_id: @project.id, user_id: current_user&.id)

        if Flipper.enabled?(:new_ship_flow_10_06, current_user)
          begin
            current_user.refresh_idv_data!
          rescue StandardError => e
            Rails.logger.error "Failed to refresh IDV data for user #{current_user.id}: #{e.message}"
            Sentry.capture_exception(e)
          end

          @project.ship!

          if current_user.idv_linked?
            redirect_to project_path(@project), notice: "Project shipped."
          else
            render "ship_idv", status: 303
          end
        else
          @project.ship!
          redirect_to project_path(@project), notice: "Project shipped."
        end
      else
        redirect_to project_path(@project), notice: "Project updated."
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project = current_user.projects.find_by(id: params[:id], is_deleted: false)
    not_found and return unless @project
    not_found and return unless @project.can_edit?

    @project.update!(is_deleted: true)
    redirect_to projects_path, notice: "Project deleted."
  end

  def check_github_repo
    unless current_user.github_user?
      render json: { ok: false, error: "GitHub account not linked (Check the tasks panel)" }, status: :unprocessable_entity
      return
    end

    repo = params[:repo].to_s.strip

    parsed_repo = Project.parse_repo(repo)
    unless parsed_repo
      render json: { ok: false, error: "Invalid GitHub repo" }, status: :unprocessable_entity
      return
    end
    org = parsed_repo[:org] || current_user.github_username
    repo_name = parsed_repo[:repo_name]

    project_param_id = params[:project_id].presence || params[:id].presence
    if project_param_id.present?
      project = current_user.projects.find_by(id: project_param_id)
      unless project
        render json: { ok: false, error: "Not authorized for this project" }, status: :forbidden
        return
      end
    end

    render json: current_user.check_github_repo(org, repo_name, project_id: project_param_id)
  rescue StandardError => e
    render json: { ok: false, error: e.message }, status: :unprocessable_entity
  end

  def check_bom
    unless current_user.present?
      render json: { ok: false, error: "Not authenticated" }, status: :unauthorized
      return
    end

    project_param_id = params[:project_id].presence || params[:id].presence
    project = current_user.projects.find_by(id: project_param_id)
    unless project
      render json: { ok: false, error: "Not authorized for this project" }, status: :forbidden
      return
    end

    unless project.repo_link.present?
      render json: { ok: false, error: "No linked GitHub repo" }, status: :unprocessable_entity
      return
    end

    exists = project.bom_file_exists?
    render json: { ok: true, exists: exists, url: project.bom_file_url }
  rescue StandardError => e
    render json: { ok: false, error: e.message }, status: :unprocessable_entity
  end

  def check_readme
    unless current_user.present?
      render json: { ok: false, error: "Not authenticated" }, status: :unauthorized
      return
    end

    project_param_id = params[:project_id].presence || params[:id].presence
    project = current_user.projects.find_by(id: project_param_id)
    unless project
      render json: { ok: false, error: "Not authorized for this project" }, status: :forbidden
      return
    end

    unless project.repo_link.present?
      render json: { ok: false, error: "No linked GitHub repo" }, status: :unprocessable_entity
      return
    end

    exists = project.readme_file_exists?
    render json: { ok: true, exists: exists, url: project.readme_file_url }
  rescue StandardError => e
    render json: { ok: false, error: e.message }, status: :unprocessable_entity
  end

  private

  def preload_project_metrics(projects)
    return if projects.blank?
    ids = Array(projects).map(&:id)
    view_counts = Project.view_counts_for(ids)
    follower_counts = Project.follower_counts_for(ids)
    Array(projects).each do |p|
      p.preloaded_view_count = view_counts[p.id].to_i
      p.preloaded_follower_count = follower_counts[p.id].to_i
    end
  end

  def project_params
    params.require(:project).permit(
      :title,
      :description,
      :repo_link,
      :demo_link,
      :readme_link,
      :project_type,
      :banner,
      :tier,
      :ship,
      :ysws,
      :ysws_other,
      :needs_funding,
      :funding_needed_cents,
      :print_legion,
      cart_screenshots: []
    )
  end
end
