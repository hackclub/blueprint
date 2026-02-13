class ToolbagController < ApplicationController
  def index
    @items = ShopItem.where(enabled: true)
                     .where.not(ticket_cost: nil)
                     .includes(:image_attachment)
                     .order(:ticket_cost, :name)
  end
end
