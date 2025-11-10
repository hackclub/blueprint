class AdultController < ApplicationController
  skip_before_action :redirect_to_age
  skip_before_action :redirect_adults

  def index
    @referral_count = User.where(referrer_id: current_user.id).count
  end
end
