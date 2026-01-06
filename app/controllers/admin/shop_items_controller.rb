class Admin::ShopItemsController < Admin::ApplicationController
  skip_before_action :require_admin!
  before_action :require_view_perms!, only: [ :index, :show ]
  before_action :require_shopkeeper_perms!, only: [ :new, :create, :edit, :update ]
  before_action :require_admin!, only: [ :destroy ]
  before_action :set_shop_item, only: [ :show, :edit, :update, :destroy ]

  def index
    @shop_items = ShopItem.includes(:image_attachment).order(:id)
  end

  def show
  end

  def new
    @shop_item = ShopItem.new
  end

  def create
    @shop_item = ShopItem.new(processed_params)

    if @shop_item.save
      redirect_to admin_shop_items_path, notice: "Shop item created successfully."
    else
      flash.now[:alert] = "There were problems creating this shop item."
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @shop_item.update(processed_params)
      redirect_to admin_shop_items_path, notice: "Shop item updated successfully."
    else
      flash.now[:alert] = "There were problems updating this shop item."
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @shop_item.destroy!
    redirect_to admin_shop_items_path, notice: "Shop item deleted successfully."
  end

  private

  def set_shop_item
    @shop_item = ShopItem.find(params[:id])
  end

  def processed_params
    attrs = shop_item_params.dup

    if attrs[:usd_cost_dollars].present?
      attrs[:usd_cost] = (attrs.delete(:usd_cost_dollars).to_f * 100).to_i
    else
      attrs.delete(:usd_cost_dollars)
    end

    attrs
  end

  def shop_item_params
    params.require(:shop_item).permit(
      :name,
      :desc,
      :ticket_cost,
      :total_stock,
      :enabled,
      :one_per_person,
      :type,
      :image,
      :usd_cost_dollars
    )
  end

  def require_view_perms!
    unless current_user&.shopkeeper_perms? || current_user&.fulfiller_perms?
      redirect_to main_app.root_path, alert: "You are not authorized to access this page."
    end
  end

  def require_shopkeeper_perms!
    unless current_user&.shopkeeper_perms?
      redirect_to main_app.root_path, alert: "You are not authorized to access this page."
    end
  end
end
