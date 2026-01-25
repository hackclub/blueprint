require "csv"

class PirateShipHelper
  ASSOCIATION_TYPES = %i[user shop_order project].freeze
  PACKAGE_TYPES = Package.package_types.keys.freeze

  def self.import_packages(csv_string:, dry_run: true, association_type: :user, package_type: nil)
    new(csv_string:, association_type:, package_type:).import_packages(dry_run:)
  end

  def initialize(csv_string:, association_type: :user, package_type: nil)
    @csv_string = csv_string
    @association_type = association_type.to_sym
    @package_type = package_type&.to_s
    raise ArgumentError, "Invalid association type: #{@association_type}" unless ASSOCIATION_TYPES.include?(@association_type)
    raise ArgumentError, "Invalid package type: #{@package_type}" if @package_type.present? && !PACKAGE_TYPES.include?(@package_type)
  end

  def import_packages(dry_run: true)
    rows = parse_csv
    tracking_numbers = rows.map { |r| normalize_tracking(r["Tracking Number"]) }.compact
    existing_tracking = Package.where(tracking_number: tracking_numbers).pluck(:tracking_number).to_set
    seen_tracking = Set.new

    packages = []
    summary = {
      rows_total: rows.size,
      would_create: 0,
      skipped_no_tracking: 0,
      skipped_missing_association: 0,
      skipped_duplicate_existing: 0,
      skipped_duplicate_in_file: 0,
      created: 0
    }

    rows.each_with_index do |row, index|
      row_number = index + 2
      tracking = normalize_tracking(row["Tracking Number"])

      if tracking.blank?
        summary[:skipped_no_tracking] += 1
        packages << build_skip_result(row_number, "skip_no_tracking", "No tracking number", row)
        next
      end

      if existing_tracking.include?(tracking)
        summary[:skipped_duplicate_existing] += 1
        packages << build_skip_result(row_number, "skip_duplicate_existing", "Package with tracking number already exists", row, tracking:)
        next
      end

      if seen_tracking.include?(tracking)
        summary[:skipped_duplicate_in_file] += 1
        packages << build_skip_result(row_number, "skip_duplicate_in_file", "Tracking number appears multiple times in CSV", row, tracking:)
        next
      end
      seen_tracking.add(tracking)

      trackable, lookup_info = resolve_trackable(row)
      if trackable.nil?
        summary[:skipped_missing_association] += 1
        packages << build_skip_result(row_number, "skip_missing_association", lookup_info[:reason], row, tracking:, association_lookup: lookup_info)
        next
      end

      attrs = build_package_attributes(row, trackable)
      summary[:would_create] += 1

      package_result = {
        row_number:,
        action: "create",
        association: lookup_info,
        dedupe_key: { tracking_number: tracking },
        attributes: attrs.except(:trackable),
        source: extract_source_info(row)
      }

      unless dry_run
        package = Package.create!(attrs.merge(trackable:))
        package_result[:created_package_id] = package.id
        summary[:created] += 1
      end

      packages << package_result
    end

    {
      dry_run:,
      association_type: @association_type,
      package_type: @package_type,
      summary:,
      packages:
    }
  end

  private

  def parse_csv
    CSV.parse(@csv_string, headers: true, liberal_parsing: true)
  end

  def normalize_email(email)
    email.to_s.strip.downcase.presence
  end

  def normalize_tracking(tracking)
    tracking.to_s.strip.presence
  end

  def resolve_trackable(row)
    case @association_type
    when :user
      resolve_user(row)
    when :shop_order
      resolve_shop_order(row)
    when :project
      resolve_project(row)
    end
  end

  def resolve_user(row)
    email = normalize_email(row["Email"])
    if email.blank?
      return [ nil, { type: "User", lookup_value: nil, reason: "Missing Email column value" } ]
    end

    user = User.with_email(email).first
    if user
      [ user, { type: "User", id: user.id, label: user.email, lookup_value: email } ]
    else
      [ nil, { type: "User", lookup_value: email, reason: "No user found matching email: #{email}" } ]
    end
  end

  def resolve_shop_order(row)
    order_id = row["Order ID"].to_s.strip.presence
    if order_id.blank?
      return [ nil, { type: "ShopOrder", lookup_value: nil, reason: "Missing Order ID column value" } ]
    end

    shop_order = ShopOrder.find_by(id: order_id)
    if shop_order
      [ shop_order, { type: "ShopOrder", id: shop_order.id, label: "Order ##{shop_order.id}", lookup_value: order_id } ]
    else
      [ nil, { type: "ShopOrder", lookup_value: order_id, reason: "No ShopOrder found with ID: #{order_id}" } ]
    end
  end

  def resolve_project(row)
    project_id = row["project_id"].to_s.strip.presence
    if project_id.blank?
      return [ nil, { type: "Project", lookup_value: nil, reason: "Missing project_id column value" } ]
    end

    project = Project.find_by(id: project_id)
    if project
      [ project, { type: "Project", id: project.id, label: project.title, lookup_value: project_id } ]
    else
      [ nil, { type: "Project", lookup_value: project_id, reason: "No Project found with ID: #{project_id}" } ]
    end
  end

  def build_package_attributes(row, trackable)
    {
      trackable:,
      package_type: @package_type,
      sent_at: parse_ship_date(row["Ship Date"]) || parse_created_date(row["Created Date"]),
      recipient_name: row["Recipient"].to_s.strip.presence,
      recipient_email: normalize_email(row["Email"]),
      tracking_number: normalize_tracking(row["Tracking Number"]),
      cost: parse_cost(row["Cost"]),
      carrier: row["Carrier"].to_s.strip.presence,
      service: row["Service"].to_s.strip.presence,
      address_line_1: row["Address Line 1"].to_s.strip.presence,
      address_line_2: row["Address Line 2"].to_s.strip.presence,
      city: row["City"].to_s.strip.presence,
      state: row["State"].to_s.strip.presence,
      postal_code: row["Zipcode"].to_s.strip.presence,
      country: row["Country"].to_s.strip.presence
    }
  end

  def parse_ship_date(date_str)
    return nil if date_str.blank?
    Date.parse(date_str).in_time_zone
  rescue ArgumentError
    nil
  end

  def parse_created_date(date_str)
    return nil if date_str.blank?
    Time.zone.parse(date_str)
  rescue ArgumentError
    nil
  end

  def parse_cost(cost_str)
    return nil if cost_str.blank?
    BigDecimal(cost_str.to_s.gsub(/[^\d.]/, ""))
  rescue ArgumentError
    nil
  end

  def extract_source_info(row)
    {
      created_date: row["Created Date"],
      ship_date: row["Ship Date"],
      tracking_status: row["Tracking Status"]
    }
  end

  def build_skip_result(row_number, action, reason, row, tracking: nil, association_lookup: nil)
    result = {
      row_number:,
      action:,
      reason:
    }
    result[:dedupe_key] = { tracking_number: tracking } if tracking
    result[:association_lookup] = association_lookup if association_lookup
    result[:source] = extract_source_info(row)
    result
  end
end
