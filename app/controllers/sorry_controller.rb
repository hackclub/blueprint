class SorryController < ApplicationController
  skip_before_action :redirect_banned_users, only: :index
  skip_before_action :redirect_to_age
  skip_before_action :redirect_adults

  layout false

  def index
    if !user_logged_in? || !current_user.is_banned
      redirect_to root_path
    end
  end
end
