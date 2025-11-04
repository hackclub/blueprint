class Admin::HcbTransactionsController < Admin::ApplicationController
  def index
    @q = params[:q].to_s.strip
    scope = HcbTransaction.includes(:hcb_grant).order(hcb_created_at: :desc)

    if @q.present?
      scope = scope.joins(:hcb_grant).where(
        "hcb_transactions.transaction_id ILIKE ? OR hcb_transactions.memo ILIKE ? OR hcb_grants.grant_id ILIKE ? OR hcb_grants.to_user_name ILIKE ?",
        "%#{@q}%", "%#{@q}%", "%#{@q}%", "%#{@q}%"
      )
    end

    @pagy, @hcb_transactions = pagy(scope, limit: 100)

    @top_missing_receipts = HcbTransaction
      .joins(:hcb_grant)
      .where(receipt_count: 0)
      .group("hcb_grants.to_user_avatar")
      .select("hcb_grants.to_user_avatar, hcb_grants.to_user_name, COUNT(hcb_transactions.id) as missing_count")
      .order("missing_count DESC")
  end
end
