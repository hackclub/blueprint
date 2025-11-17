class Admin::ShopOrdersController < Admin::ApplicationController
  skip_before_action :require_admin!
  before_action :require_fulfiller_perms!

  def index
    @shop_orders = ShopOrder.includes(:user, :shop_item, :approved_by, :fufilled_by, :rejected_by, :on_hold_by)

    status = params[:status].presence || "pending"
    @shop_orders = @shop_orders.where(state: status) unless status == "all"

    @shop_orders = @shop_orders.order(created_at: :desc)
  end

  def show
    @shop_order = ShopOrder.find(params[:id])
  end

  def approve
    @shop_order = ShopOrder.find(params[:id])
    @shop_order.update!(
      state: :approved,
      approved_by: current_user,
      approved_at: Time.current
    )
    redirect_to admin_shop_orders_path, notice: "Order approved successfully."
  end

  def reject
    @shop_order = ShopOrder.find(params[:id])
    reason = params[:rejection_reason].presence || params[:hold_reason]
    @shop_order.update!(
      state: :rejected,
      rejected_by: current_user,
      rejected_at: Time.current,
      rejection_reason: reason
    )
    redirect_to admin_shop_orders_path, notice: "Order rejected."
  end

  def hold
    @shop_order = ShopOrder.find(params[:id])
    if @shop_order.on_hold?
      @shop_order.update!(
        state: :pending,
        on_hold_by: nil,
        on_hold_at: nil,
        hold_reason: nil
      )
      redirect_to admin_shop_orders_path, notice: "Hold removed from order."
    else
      @shop_order.update!(
        state: :on_hold,
        on_hold_by: current_user,
        on_hold_at: Time.current,
        hold_reason: params[:hold_reason]
      )
      redirect_to admin_shop_orders_path, notice: "Order put on hold."
    end
  end

  def fulfill
    @shop_order = ShopOrder.find(params[:id])
    cost_cents = if params[:fufillment_usd_cost_dollars].present?
      (params[:fufillment_usd_cost_dollars].to_f * 100).to_i
    else
      params[:fufillment_usd_cost]&.to_i
    end

    @shop_order.update!(
      state: :fufilled,
      fufilled_by: current_user,
      fufilled_at: Time.current,
      fufillment_usd_cost: cost_cents,
      internal_notes: params[:internal_notes],
      tracking_number: params[:tracking]
    )
    redirect_to admin_shop_orders_path, notice: "Order fulfilled."
  end

  def update_notes
    @shop_order = ShopOrder.find(params[:id])
    @shop_order.update!(internal_notes: params[:internal_notes])
    redirect_to admin_shop_order_path(@shop_order), notice: "Notes updated."
  end

  private

  def require_fulfiller_perms!
    unless current_user&.fulfiller_perms?
      redirect_to main_app.root_path, alert: "You are not authorized to access this page."
    end
  end
end
