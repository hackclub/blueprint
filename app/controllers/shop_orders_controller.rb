class ShopOrdersController < ApplicationController
  def index
    @shop_orders = current_user.shop_orders.includes(:shop_item).order(created_at: :desc)
  end

  def new
    unless current_user.idv_linked?
      redirect_to idv_path and return
    end

    @shop_item = ShopItem.find(params[:item_id])

    unless @shop_item.enabled
      raise ActiveRecord::RecordNotFound
    end

    @idv_data = current_user.fetch_idv
    @addresses = @idv_data.dig(:identity, :addresses) || []
    @shop_order = ShopOrder.new(shop_item: @shop_item, user: current_user)
  rescue ActiveRecord::RecordNotFound
    raise ActionController::RoutingError.new("Not Found")
  end

  def create
    @shop_item = ShopItem.find(params[:shop_order][:shop_item_id])

    unless @shop_item.enabled
      raise ActionController::RoutingError.new("Not Found")
    end

    @shop_order = ShopOrder.new(shop_order_params)
    @shop_order.user = current_user
    @shop_order.shop_item = @shop_item

    total_cost = (@shop_item.ticket_cost || 0) * (@shop_order.quantity || 0)
    if current_user.tickets < total_cost
      @shop_order.errors.add(:base, "Insufficient tickets. You need #{total_cost} tickets but only have #{current_user.tickets}.")
      @idv_data = current_user.fetch_idv
      @addresses = @idv_data.dig(:identity, :addresses) || []
      render :new, status: :unprocessable_entity
      return
    end

    if @shop_order.save
      redirect_to shop_orders_path, notice: "Order placed successfully!"
    else
      @idv_data = current_user.fetch_idv
      @addresses = @idv_data.dig(:identity, :addresses) || []
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    raise ActionController::RoutingError.new("Not Found")
  end

  private

  def shop_order_params
    params.require(:shop_order).permit(:quantity, :frozen_address)
  end
end
