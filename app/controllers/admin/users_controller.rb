class Admin::UsersController < Admin::ApplicationController
  skip_before_action :require_admin!, only: [ :index, :show, :update_internal_notes, :stop_impersonating ]
  skip_before_action :authenticate_user!, only: [ :stop_impersonating ]
  skip_before_action :ensure_allowed_user!, only: [ :stop_impersonating ]
  before_action :require_reviewer_perms!, only: [ :index, :show, :update_internal_notes ]
  before_action :require_impersonating!, only: [ :stop_impersonating ]

  def index
    @q = params[:q].to_s.strip

    users = User.order(created_at: :desc)

    if @q.present?
      like = "%#{@q}%"
      users = users.where(
        "users.id::text ILIKE :q OR users.username ILIKE :q OR users.email ILIKE :q OR users.slack_id ILIKE :q",
        q: like
      )
    end

    @pagy, @users = pagy(users, items: 20)
  end

  def show
    @user = User.find(params[:id])
    not_found unless @user
  end

  def grant_reviewer
    @user = User.find(params[:id])
    @user.update!(reviewer: true)
    redirect_to admin_user_path(@user), notice: "User granted reviewer permissions"
  end

  def revoke_reviewer
    @user = User.find(params[:id])
    @user.update!(reviewer: false)
    redirect_to admin_user_path(@user), notice: "Reviewer permissions revoked"
  end

  def grant_fulfiller
    @user = User.find(params[:id])
    @user.update!(fulfiller: true)
    redirect_to admin_user_path(@user), notice: "User granted fulfiller permissions"
  end

  def revoke_fulfiller
    @user = User.find(params[:id])
    @user.update!(fulfiller: false)
    redirect_to admin_user_path(@user), notice: "Fulfiller permissions revoked"
  end

  def grant_admin
    @user = User.find(params[:id])
    @user.update!(admin: true)
    redirect_to admin_user_path(@user), notice: "User granted admin permissions"
  end

  def revoke_admin
    @user = User.find(params[:id])
    @user.update!(admin: false)
    redirect_to admin_user_path(@user), notice: "Admin permissions revoked"
  end

  def ban
    @user = User.find(params[:id])
    @user.update!(is_banned: true, ban_type: :blueprint)
    redirect_to admin_user_path(@user), notice: "User banned"
  end

  def unban
    @user = User.find(params[:id])
    @user.update!(is_banned: false, ban_type: nil)
    redirect_to admin_user_path(@user), notice: "User unbanned"
  end

  def revoke_to_user
    @user = User.find(params[:id])
    @user.update!(admin: false, reviewer: false, fulfiller: false)
    redirect_to admin_user_path(@user), notice: "All permissions revoked"
  end

  def update_internal_notes
    @user = User.find(params[:id])

    frozen_notes = params[:user][:frozen_internal_notes].presence
    current_notes = @user.internal_notes.presence

    if frozen_notes != current_notes
      @conflict_frozen = frozen_notes
      @conflict_current = current_notes
      @conflict_new = params[:user][:internal_notes]

      respond_to do |format|
        format.html { render :show, status: :conflict }
        format.turbo_stream do
          flash.now[:alert] = "Conflict detected! Notes were modified by someone else."
          render turbo_stream: turbo_stream.replace("user_notes_#{@user.id}", partial: "admin/users/user_notes_conflict", locals: { user: @user, frozen: @conflict_frozen, current: @conflict_current, new_notes: @conflict_new })
        end
      end
      return
    end

    if @user.update(internal_notes: params[:user][:internal_notes])
      respond_to do |format|
        format.html { redirect_to admin_user_path(@user), notice: "Internal notes updated successfully" }
        format.turbo_stream do
          flash.now[:notice] = "Internal notes updated successfully"
          render turbo_stream: turbo_stream.replace("user_notes_#{@user.id}", partial: "admin/users/user_notes_form", locals: { user: @user })
        end
      end
    else
      respond_to do |format|
        format.html { render :show, status: :unprocessable_entity }
        format.turbo_stream do
          flash.now[:alert] = "Failed to update internal notes"
          render turbo_stream: turbo_stream.replace("user_notes_#{@user.id}", partial: "admin/users/user_notes_form", locals: { user: @user })
        end
      end
    end
  end

  def impersonate
    unless current_user&.admin?
      return redirect_to(main_app.root_path, alert: "Not authorized.")
    end

    if session[:original_id].present?
      return redirect_back(fallback_location: admin_user_path(params[:id]), alert: "Already impersonating. Stop first.")
    end

    user = User.find_by(id: params[:id])
    return redirect_back(fallback_location: admin_users_path, alert: "User not found") unless user
    return redirect_back(fallback_location: admin_user_path(user), alert: "Cannot impersonate yourself") if user.id == current_user.id
    return redirect_back(fallback_location: admin_user_path(user), alert: "Cannot impersonate admins/staff") if user.admin? || user.special_perms?

    previous_admin_id = current_user.id
    reset_session
    session[:original_id] = previous_admin_id
    session[:user_id] = user.id
    redirect_to main_app.root_path, notice: "Now impersonating #{user.display_name}"
  end

  def stop_impersonating
    unless session[:original_id].present?
      return redirect_to main_app.root_path, alert: "Not currently impersonating"
    end

    orig_id = session[:original_id]
    reset_session
    session[:user_id] = orig_id
    redirect_to main_app.root_path, notice: "Stopped impersonating"
  end

  private

  def user_params
    params.require(:user).permit(:internal_notes, :frozen_internal_notes)
  end

  def require_reviewer_perms!
    unless current_user&.reviewer_perms?
      redirect_to main_app.root_path, alert: "You are not authorized to access this page."
    end
  end

  def require_impersonating!
    unless session[:original_id].present?
      redirect_to main_app.root_path, alert: "Not currently impersonating."
    end
  end
end
