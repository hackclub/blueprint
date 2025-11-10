class AmdController < ApplicationController
  allow_unauthenticated_access only: %i[index]

  def index
    redirect_to root_path(utm_source: "amd"), allow_other_host: false
  end
end
