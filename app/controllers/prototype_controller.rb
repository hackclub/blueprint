class PrototypeController < ApplicationController
  http_basic_authenticate_with name: ENV["PROTOTYPE_USER"], password: ENV["PROTOTYPE_PASS"]
  layout false

  def index
  end
end
