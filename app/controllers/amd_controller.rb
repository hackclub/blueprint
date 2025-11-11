class AmdController < ApplicationController
  allow_unauthenticated_access only: %i[index]
  skip_after_action :track_page_view, only: :index

  def index
    redirect_to root_path(utm_source: "amd"), allow_other_host: false
  end
end
