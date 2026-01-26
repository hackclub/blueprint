class PackagesController < ApplicationController
  def customs_receipt
    package = Package.find_by(id: params[:id])
    return not_found unless package
    return not_found unless package.owner == current_user

    pdf_data = package.generate_receipt!

    send_data pdf_data,
      filename: "customs-receipt-#{package.tracking_number}.pdf",
      type: "application/pdf",
      disposition: "inline"
  end
end
