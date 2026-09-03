# Run with:
#   rails runner script/backfill_airtable_hours.rb              # dry run (default), no writes
#   WRITE=1 rails runner script/backfill_airtable_hours.rb      # patch Airtable rows
#
# Earlier versions of Project#upload_to_airtable! sent the sum of design + build
# hours as "Optional - Override Hours Spent" for the Build upload. Airtable
# Design rows from the earlier design approval hold the correct design-only
# hours and are treated as source of truth — we subtract the Design row's hours
# from each Build row in place. Airtable is authoritative for hour values
# (admins may have edited them since), so we never read hour counts from the DB.
#
# Schema of what's in Airtable per project today (typical):
#   Design row: a               ← correct
#   Build row:  a + b           ← buggy, patch to b
#   Build row:  a + b + ...     ← buggy, patch by subtracting design total
#
# Pre-Nov-2025 uploads used "Review Type = nil" — we treat a lone nil row as a
# legacy Design row. Multiple nil rows mean ambiguity; we skip + flag.
#
# Required env: AIRTABLE_PAT, AIRTABLE_BASE_ID
# Optional env: PROD_DATABASE_URL — read from that DB (only for scope/flagging,
#               never for hour values).

require "faraday"
require "json"
require "uri"

if ENV["PROD_DATABASE_URL"].present?
  ActiveRecord::Base.establish_connection(ENV["PROD_DATABASE_URL"])
  puts "Connected to PROD_DATABASE_URL"
end

TABLE_ID = "tblRH1aELwmy7rgEU"
HOURS_FIELD = "Optional - Override Hours Spent"
PROJECT_ID_FIELD = "BP Project ID"
REVIEW_TYPE_FIELD = "Review Type"
MODIFIED_FLAG_FIELD = "0529 Modified"

dry_run = ENV["WRITE"] != "1"
pat = ENV.fetch("AIRTABLE_PAT")
base_id = ENV.fetch("AIRTABLE_BASE_ID")

def airtable_get(url, pat)
  Faraday.get(url) { |req| req.headers["Authorization"] = "Bearer #{pat}" }
end

def airtable_patch(url, pat, fields)
  Faraday.patch(url) do |req|
    req.headers["Authorization"] = "Bearer #{pat}"
    req.headers["Content-Type"] = "application/json"
    req.body = { fields: fields, typecast: true }.to_json
  end
end

def find_records_for_project(base_id:, pat:, project_id:)
  formula = "{#{PROJECT_ID_FIELD}}=#{project_id}"
  url = "https://api.airtable.com/v0/#{base_id}/#{TABLE_ID}?" \
        "filterByFormula=#{URI.encode_www_form_component(formula)}"
  resp = airtable_get(url, pat)
  raise "Airtable GET failed (#{resp.status}): #{resp.body}" unless resp.success?
  JSON.parse(resp.body)["records"] || []
end

EXCLUDED_YSWS = %w[led hackpad squeak].freeze

# Manual carve-outs — projects we leave alone for known reasons.
# #611: has two Build rows that can't both be derived from one design; manual fix.
SKIP_PROJECT_IDS = [ 611 ].freeze

# NOTE: `where.not(ysws: [...])` excludes NULLs in SQL — projects with ysws=nil
# follow the default branch and must stay in scope.
scope = Project.where(review_status: :build_approved)
  .where("ysws IS NULL OR ysws NOT IN (?)", EXCLUDED_YSWS)
total = scope.count
puts "#{dry_run ? '[DRY RUN] ' : ''}Found #{total} build-approved projects (excluding #{EXCLUDED_YSWS.join(', ')})."
puts

patched = 0
skipped = 0
flagged = []  # collected and printed at the end for easy review

# Snapshot every project's full Airtable records before we touch anything.
# Written once per run (dry or live), so we always have a restore point.
backup_path = Rails.root.join("tmp", "airtable_hours_backup_#{Time.current.strftime('%Y%m%d_%H%M%S')}.json")
backup_data = {}

scope.find_each.with_index(1) do |project, i|
  if SKIP_PROJECT_IDS.include?(project.id)
    puts "[#{i}/#{total}] Project ##{project.id}: in SKIP_PROJECT_IDS, leaving alone"
    skipped += 1
    next
  end

  begin
    records = find_records_for_project(base_id: base_id, pat: pat, project_id: project.id)
  rescue => e
    puts "[#{i}/#{total}] Project ##{project.id}: lookup failed — #{e.message}"
    skipped += 1
    next
  end

  # Snapshot id + hours + review type for every Airtable row we touch.
  backup_data[project.id] = records.map do |r|
    {
      airtable_id: r["id"],
      review_type: r.dig("fields", REVIEW_TYPE_FIELD),
      hours: r.dig("fields", HOURS_FIELD),
      created_time: r["createdTime"]
    }
  end

  design_rows = records.select { |r| r.dig("fields", REVIEW_TYPE_FIELD) == "Design" }
  build_rows  = records.select { |r| r.dig("fields", REVIEW_TYPE_FIELD) == "Build" }
  nil_rows    = records.select { |r| r.dig("fields", REVIEW_TYPE_FIELD).nil? }

  if build_rows.empty?
    puts "[#{i}/#{total}] Project ##{project.id}: no Build row in Airtable, skip"
    skipped += 1
    next
  end

  # DB sanity: more than one admin-approved design review on a project means
  # the simple "subtract design" model doesn't cleanly apply. Flag and skip.
  approved_admin_designs = project.design_reviews
    .where(result: "approved", invalidated: false, admin_review: true).count
  if approved_admin_designs > 1
    flagged << "Project ##{project.id}: #{approved_admin_designs} admin design reviews in DB — needs manual review"
    puts "[#{i}/#{total}] Project ##{project.id}: #{approved_admin_designs} admin design reviews, FLAG"
    skipped += 1
    next
  end

  # Resolve which Airtable rows to use as the Design source of truth.
  design_source_rows =
    if design_rows.any?
      design_rows
    elsif nil_rows.size == 1
      nil_rows  # legacy design upload, before the Review Type field existed
    elsif nil_rows.size >= 2
      flagged << "Project ##{project.id}: #{nil_rows.size} nil-type rows, ambiguous — needs manual review"
      puts "[#{i}/#{total}] Project ##{project.id}: #{nil_rows.size} ambiguous nil rows, FLAG"
      skipped += 1
      next
    else
      []
    end

  if design_source_rows.empty?
    # No Design row anywhere in Airtable. If the DB also has no admin design
    # review, the project skipped design — the Build row's current value is
    # already build-only (old buggy sum had 0 design contribution). Leave it.
    # If the DB DOES show an approved design, the design upload is missing and
    # we can't compute the delta — flag for manual fix.
    if approved_admin_designs == 0
      puts "[#{i}/#{total}] Project ##{project.id}: no design (Airtable or DB), build hours already correct, skip"
      skipped += 1
    else
      flagged << "Project ##{project.id}: design exists in DB but no Design row in Airtable — needs re-upload"
      puts "[#{i}/#{total}] Project ##{project.id}: DB has design but Airtable doesn't, FLAG"
      skipped += 1
    end
    next
  end

  design_hours_values = design_source_rows.map { |r| r.dig("fields", HOURS_FIELD)&.to_f }.compact
  design_total = design_hours_values.max
  if design_total.nil?
    flagged << "Project ##{project.id}: Design row(s) present but no hours value — needs manual review"
    puts "[#{i}/#{total}] Project ##{project.id}: design row(s) with no hours, FLAG"
    skipped += 1
    next
  end

  build_rows.each do |rec|
    current = rec.dig("fields", HOURS_FIELD)&.to_f
    if current.nil?
      puts "[#{i}/#{total}] Project ##{project.id} rec=#{rec['id']}: build row has no hours, skip"
      skipped += 1
      next
    end

    corrected = (current - design_total).round(2)

    if (current - corrected).abs < 0.01
      puts "[#{i}/#{total}] Project ##{project.id} rec=#{rec['id']}: already #{current.round(2)}h (design=#{design_total}h), skip"
      skipped += 1
      next
    end

    if corrected < 0
      flagged << "Project ##{project.id} rec=#{rec['id']}: corrected=#{corrected}h < 0 (current=#{current}h, design=#{design_total}h)"
      puts "[#{i}/#{total}] Project ##{project.id} rec=#{rec['id']}: " \
           "corrected=#{corrected}h < 0 (current=#{current.round(2)}h, design=#{design_total}h), FLAG and leave alone"
      skipped += 1
      next
    end

    msg = "[#{i}/#{total}] Project ##{project.id} rec=#{rec['id']}: " \
          "#{current.round(2)}h → #{corrected}h [design=#{design_total}h]"

    if dry_run
      puts "[DRY RUN] #{msg}"
    else
      url = "https://api.airtable.com/v0/#{base_id}/#{TABLE_ID}/#{rec['id']}"
      resp = airtable_patch(url, pat, { HOURS_FIELD => corrected, MODIFIED_FLAG_FIELD => true })
      if resp.success?
        puts "#{msg} ✓"
        patched += 1
      else
        puts "#{msg} ✗ (#{resp.status}: #{resp.body})"
        skipped += 1
      end
    end
  end
end

File.write(backup_path, JSON.pretty_generate(backup_data))
puts
puts "Backup written: #{backup_path} (#{backup_data.size} projects, #{backup_data.values.sum(&:size)} rows)"
puts
puts "#{dry_run ? 'DRY RUN summary' : 'Done'}: patched=#{patched}, skipped=#{skipped}"
if flagged.any?
  puts
  puts "FLAGGED (#{flagged.size}) — needs manual review:"
  flagged.each { |f| puts "  - #{f}" }
end
puts
puts "Re-run with WRITE=1 to apply." if dry_run
