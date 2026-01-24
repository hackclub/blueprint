class Admin::PirateShipImportsController < Admin::ApplicationController
  ASSOCIATION_TYPES = %w[user shop_order project].freeze

  def new
  end

  def preview
    @association_type = normalized_association_type!
    upload = params.require(:csv_file)

    csv_string = upload.read
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(csv_string),
      filename: upload.original_filename.presence || "pirateship.csv",
      content_type: upload.content_type.presence || "text/csv"
    )

    @csv_blob_signed_id = blob.signed_id
    @result = PirateShipHelper.import_packages(
      csv_string:,
      dry_run: true,
      association_type: @association_type.to_sym
    )

    render :preview
  rescue ActionController::ParameterMissing
    redirect_to new_admin_pirate_ship_import_path, alert: "Please choose a CSV file to upload."
  rescue ArgumentError => e
    redirect_to new_admin_pirate_ship_import_path, alert: e.message
  rescue StandardError => e
    redirect_to new_admin_pirate_ship_import_path, alert: "Preview failed: #{e.message}"
  end

  def create
    @association_type = normalized_association_type!
    blob = ActiveStorage::Blob.find_signed!(params.require(:csv_blob_signed_id))
    csv_string = blob.download

    @result = PirateShipHelper.import_packages(
      csv_string:,
      dry_run: false,
      association_type: @association_type.to_sym
    )

    created = @result.dig(:summary, :created)
    skipped = @result.dig(:summary, :rows_total).to_i - created.to_i

    redirect_to new_admin_pirate_ship_import_path,
      notice: "Import complete: created #{created} package(s). Skipped #{skipped} row(s)."
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    redirect_to new_admin_pirate_ship_import_path, alert: "Import expired or invalid. Please re-upload the CSV."
  rescue StandardError => e
    redirect_to new_admin_pirate_ship_import_path, alert: "Import failed: #{e.message}"
  end

  private

  def normalized_association_type!
    t = params[:association_type].to_s
    raise ArgumentError, "Invalid association type." unless ASSOCIATION_TYPES.include?(t)
    t
  end
end
