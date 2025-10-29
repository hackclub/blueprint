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
    @user.update!(role: "reviewer")
    redirect_to admin_user_path(@user), notice: "User granted reviewer role"
  end

  def revoke_to_user
    @user = User.find(params[:id])
    @user.update!(role: "user")
    redirect_to admin_user_path(@user), notice: "User role revoked to user"
  end

  def update_internal_notes
    @user = User.find(params[:id])

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
    params.require(:user).permit(:internal_notes)
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
