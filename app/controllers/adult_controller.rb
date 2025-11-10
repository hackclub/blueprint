class AdultController < ApplicationController
  skip_before_action :redirect_to_age
  skip_before_action :redirect_adults
  allow_unauthenticated_access only: %i[index]

  def index
    if user_logged_in?
      @referral_count = User.where(referrer_id: current_user.id).count
    end
  end
end
