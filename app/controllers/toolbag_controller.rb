class ToolbagController < ApplicationController
  def index
    @items = ShopItem.where(enabled: true)
                     .includes(:image_attachment)
                     .order(:ticket_cost, :name)
  end
end
