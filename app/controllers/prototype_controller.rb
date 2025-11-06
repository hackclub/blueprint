class PrototypeController < ApplicationController
  http_basic_authenticate_with name: ENV["PROTOTYPE_USER"], password: ENV["PROTOTYPE_PASS"]
  allow_unauthenticated_access only: %i[index]
  layout "prototype"

  def index
  end
end
