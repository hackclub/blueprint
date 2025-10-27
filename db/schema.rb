# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_10_27_211837) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ahoy_events", force: :cascade do |t|
    t.bigint "visit_id"
    t.bigint "user_id"
    t.string "name"
    t.jsonb "properties"
    t.datetime "time"
    t.index "((properties ->> 'project_id'::text))", name: "index_ahoy_events_on_project_id"
    t.index ["name", "time"], name: "index_ahoy_events_on_name_and_time"
    t.index ["properties"], name: "index_ahoy_events_on_properties", opclass: :jsonb_path_ops, using: :gin
    t.index ["user_id", "name"], name: "index_ahoy_events_on_user_id_and_name"
    t.index ["user_id"], name: "index_ahoy_events_on_user_id"
    t.index ["visit_id"], name: "index_ahoy_events_on_visit_id"
  end

  create_table "ahoy_visits", force: :cascade do |t|
    t.string "visit_token"
    t.string "visitor_token"
    t.bigint "user_id"
    t.string "ip"
    t.text "user_agent"
    t.text "referrer"
    t.string "referring_domain"
    t.text "landing_page"
    t.string "browser"
    t.string "os"
    t.string "device_type"
    t.string "country"
    t.string "region"
    t.string "city"
    t.float "latitude"
    t.float "longitude"
    t.string "utm_source"
    t.string "utm_medium"
    t.string "utm_term"
    t.string "utm_content"
    t.string "utm_campaign"
    t.string "app_version"
    t.string "os_version"
    t.string "platform"
    t.datetime "started_at"
    t.index ["user_id"], name: "index_ahoy_visits_on_user_id"
    t.index ["visit_token"], name: "index_ahoy_visits_on_visit_token", unique: true
    t.index ["visitor_token", "started_at"], name: "index_ahoy_visits_on_visitor_token_and_started_at"
  end

  create_table "airtable_syncs", force: :cascade do |t|
    t.string "airtable_id"
    t.datetime "last_synced_at"
    t.string "synced_attributes_hash"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "record_identifier", null: false
    t.index ["record_identifier"], name: "index_airtable_syncs_on_record_identifier", unique: true
  end

  create_table "allowed_emails", force: :cascade do |t|
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_allowed_emails_on_email", unique: true
  end

  create_table "blazer_audits", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "query_id"
    t.text "statement"
    t.string "data_source"
    t.datetime "created_at"
    t.index ["query_id"], name: "index_blazer_audits_on_query_id"
    t.index ["user_id"], name: "index_blazer_audits_on_user_id"
  end

  create_table "blazer_checks", force: :cascade do |t|
    t.bigint "creator_id"
    t.bigint "query_id"
    t.string "state"
    t.string "schedule"
    t.text "emails"
    t.text "slack_channels"
    t.string "check_type"
    t.text "message"
    t.datetime "last_run_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_checks_on_creator_id"
    t.index ["query_id"], name: "index_blazer_checks_on_query_id"
  end

  create_table "blazer_dashboard_queries", force: :cascade do |t|
    t.bigint "dashboard_id"
    t.bigint "query_id"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dashboard_id"], name: "index_blazer_dashboard_queries_on_dashboard_id"
    t.index ["query_id"], name: "index_blazer_dashboard_queries_on_query_id"
  end

  create_table "blazer_dashboards", force: :cascade do |t|
    t.bigint "creator_id"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_dashboards_on_creator_id"
  end

  create_table "blazer_queries", force: :cascade do |t|
    t.bigint "creator_id"
    t.string "name"
    t.text "description"
    t.text "statement"
    t.string "data_source"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_queries_on_creator_id"
  end

  create_table "build_reviews", force: :cascade do |t|
    t.bigint "reviewer_id", null: false
    t.bigint "project_id", null: false
    t.boolean "admin_review"
    t.string "reason"
    t.text "feedback"
    t.integer "result"
    t.boolean "invalidated", default: false
    t.integer "frozen_duration_seconds"
    t.integer "frozen_entry_count"
    t.integer "frozen_tier"
    t.float "ticket_multiplier"
    t.integer "ticket_offset"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "tier_override"
    t.float "hours_override"
    t.index ["project_id"], name: "index_build_reviews_on_project_id"
    t.index ["reviewer_id", "project_id"], name: "index_build_reviews_on_reviewer_id_and_project_id", unique: true, where: "(invalidated = false)"
    t.index ["reviewer_id"], name: "index_build_reviews_on_reviewer_id"
  end

  create_table "design_reviews", force: :cascade do |t|
    t.bigint "reviewer_id", null: false
    t.bigint "project_id", null: false
    t.float "hours_override"
    t.boolean "admin_review"
    t.string "reason"
    t.integer "grant_override_cents"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "result"
    t.text "feedback"
    t.integer "tier_override"
    t.boolean "invalidated", default: false
    t.integer "frozen_funding_needed_cents"
    t.integer "frozen_duration_seconds"
    t.integer "frozen_tier"
    t.integer "frozen_entry_count"
    t.index ["project_id"], name: "index_design_reviews_on_project_id"
    t.index ["reviewer_id", "project_id"], name: "index_design_reviews_on_reviewer_id_and_project_id", unique: true, where: "(invalidated = false)"
    t.index ["reviewer_id"], name: "index_design_reviews_on_reviewer_id"
  end

  create_table "disco_recommendations", force: :cascade do |t|
    t.string "subject_type"
    t.bigint "subject_id"
    t.string "item_type"
    t.bigint "item_id"
    t.string "context"
    t.float "score"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_type", "item_id"], name: "index_disco_recommendations_on_item"
    t.index ["subject_type", "subject_id"], name: "index_disco_recommendations_on_subject"
  end

  create_table "email_tracks", force: :cascade do |t|
    t.string "email"
    t.datetime "tracked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "flipper_features", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.string "feature_key", null: false
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "follows", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "project_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_follows_on_project_id"
    t.index ["user_id", "project_id"], name: "index_follows_on_user_id_and_project_id", unique: true
    t.index ["user_id"], name: "index_follows_on_user_id"
  end

  create_table "hcb_grants", force: :cascade do |t|
    t.string "org_id", null: false
    t.string "grant_id", null: false
    t.string "status"
    t.integer "initial_amount_cents"
    t.integer "balance_cents"
    t.string "to_user_name"
    t.text "to_user_avatar"
    t.text "for_reason"
    t.datetime "issued_at"
    t.string "source_url"
    t.datetime "first_seen_at", null: false
    t.datetime "last_seen_at", null: false
    t.datetime "last_synced_at"
    t.integer "sync_failures_count", default: 0, null: false
    t.text "last_sync_error"
    t.datetime "soft_deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["last_seen_at"], name: "index_hcb_grants_on_last_seen_at"
    t.index ["org_id", "grant_id"], name: "index_hcb_grants_on_org_id_and_grant_id", unique: true
    t.index ["soft_deleted_at"], name: "index_hcb_grants_on_soft_deleted_at"
  end

  create_table "hcb_transactions", force: :cascade do |t|
    t.bigint "hcb_grant_id", null: false
    t.string "org_id", null: false
    t.string "transaction_id", null: false
    t.string "status"
    t.integer "amount_cents"
    t.integer "receipt_count"
    t.text "memo"
    t.datetime "hcb_created_at"
    t.string "source_url"
    t.datetime "first_seen_at", null: false
    t.datetime "last_seen_at", null: false
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hcb_grant_id"], name: "index_hcb_transactions_on_hcb_grant_id"
    t.index ["last_seen_at"], name: "index_hcb_transactions_on_last_seen_at"
    t.index ["org_id", "transaction_id"], name: "index_hcb_transactions_on_org_id_and_transaction_id", unique: true
  end

  create_table "journal_entries", force: :cascade do |t|
    t.integer "duration_seconds", default: 0, null: false
    t.bigint "user_id", null: false
    t.bigint "project_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "content"
    t.string "summary"
    t.bigint "views", default: [], null: false, array: true
    t.string "review_type"
    t.bigint "review_id"
    t.index ["project_id", "created_at"], name: "index_journal_entries_unreviewed_by_project", where: "(review_id IS NULL)"
    t.index ["project_id"], name: "index_journal_entries_on_project_id"
    t.index ["review_type", "review_id"], name: "index_journal_entries_on_review"
    t.index ["review_type", "review_id"], name: "index_journal_entries_on_review_type_and_review_id"
    t.index ["user_id"], name: "index_journal_entries_on_user_id"
  end

  create_table "kudos", force: :cascade do |t|
    t.text "content"
    t.bigint "user_id", null: false
    t.bigint "project_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_kudos_on_project_id"
    t.index ["user_id"], name: "index_kudos_on_user_id"
  end

  create_table "manual_ticket_adjustments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "adjustment"
    t.string "internal_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_manual_ticket_adjustments_on_user_id"
  end

  create_table "one_time_passwords", force: :cascade do |t|
    t.string "secret", null: false
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email", null: false
    t.index ["email"], name: "index_one_time_passwords_on_email"
  end

  create_table "project_grants", force: :cascade do |t|
    t.integer "tier"
    t.integer "grant_cents"
    t.bigint "project_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_project_grants_on_project_id"
  end

  create_table "project_user_views", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "user_id", null: false
    t.datetime "first_viewed_at", default: -> { "now()" }, null: false
    t.index ["project_id", "user_id"], name: "index_puv_on_project_id_user_id", unique: true
    t.index ["user_id"], name: "index_project_user_views_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.string "demo_link"
    t.string "readme_link"
    t.string "repo_link"
    t.string "project_type"
    t.string "review_status"
    t.boolean "is_deleted", default: false
    t.integer "views_count", default: 0, null: false
    t.string "hackatime_project_keys", default: [], array: true
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "tier"
    t.boolean "needs_funding", default: true
    t.string "ysws"
    t.integer "funding_needed_cents", default: 0, null: false
    t.integer "approved_tier"
    t.integer "approved_funding_cents"
    t.boolean "print_legion", default: false, null: false
    t.integer "journal_entries_count", default: 0, null: false
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "shop_items", force: :cascade do |t|
    t.boolean "enabled"
    t.integer "ticket_cost"
    t.integer "usd_cost"
    t.string "name"
    t.string "desc"
    t.boolean "one_per_person"
    t.integer "total_stock"
    t.string "type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "shop_orders", force: :cascade do |t|
    t.integer "state", default: 0, null: false
    t.bigint "user_id", null: false
    t.bigint "shop_item_id", null: false
    t.integer "frozen_unit_ticket_cost"
    t.integer "frozen_unit_usd_cost"
    t.integer "quantity"
    t.string "internal_notes"
    t.datetime "approved_at"
    t.bigint "approved_by_id"
    t.datetime "fufilled_at"
    t.bigint "fufilled_by_id"
    t.integer "fufillment_usd_cost"
    t.datetime "rejected_at"
    t.bigint "rejected_by_id"
    t.string "rejection_reason"
    t.datetime "on_hold_at"
    t.bigint "on_hold_by_id"
    t.string "hold_reason"
    t.jsonb "frozen_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_shop_orders_on_approved_by_id"
    t.index ["fufilled_by_id"], name: "index_shop_orders_on_fufilled_by_id"
    t.index ["on_hold_by_id"], name: "index_shop_orders_on_on_hold_by_id"
    t.index ["rejected_by_id"], name: "index_shop_orders_on_rejected_by_id"
    t.index ["shop_item_id"], name: "index_shop_orders_on_shop_item_id"
    t.index ["user_id"], name: "index_shop_orders_on_user_id"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "stored_recommendations", force: :cascade do |t|
    t.string "key"
    t.jsonb "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_stored_recommendations_on_key", unique: true
  end

  create_table "task_lists", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_task_lists_on_user_id", unique: true
  end

  create_table "timeline_items", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "type", null: false
    t.jsonb "data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_timeline_items_on_project_id"
    t.index ["type"], name: "index_timeline_items_on_type"
  end

  create_table "users", force: :cascade do |t|
    t.string "avatar"
    t.string "slack_id"
    t.string "username"
    t.string "timezone_raw"
    t.integer "role", default: 0, null: false
    t.boolean "is_banned", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email", null: false
    t.boolean "is_mcg", default: false, null: false
    t.string "github_username"
    t.datetime "last_active"
    t.bigint "github_installation_id"
    t.bigint "referrer_id"
    t.string "identity_vault_access_token"
    t.string "identity_vault_id"
    t.boolean "ysws_verified"
    t.text "internal_notes"
    t.index ["referrer_id"], name: "index_users_on_referrer_id"
  end

  create_table "versions", force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object"
    t.jsonb "object_changes"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
    t.index ["object_changes"], name: "index_versions_on_object_changes", using: :gin
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "build_reviews", "projects"
  add_foreign_key "build_reviews", "users", column: "reviewer_id"
  add_foreign_key "design_reviews", "projects"
  add_foreign_key "design_reviews", "users", column: "reviewer_id"
  add_foreign_key "follows", "projects"
  add_foreign_key "follows", "users"
  add_foreign_key "hcb_transactions", "hcb_grants"
  add_foreign_key "journal_entries", "projects"
  add_foreign_key "journal_entries", "users"
  add_foreign_key "kudos", "projects"
  add_foreign_key "kudos", "users"
  add_foreign_key "manual_ticket_adjustments", "users"
  add_foreign_key "project_grants", "projects"
  add_foreign_key "project_user_views", "projects"
  add_foreign_key "project_user_views", "users"
  add_foreign_key "projects", "users"
  add_foreign_key "shop_orders", "shop_items"
  add_foreign_key "shop_orders", "users"
  add_foreign_key "shop_orders", "users", column: "approved_by_id"
  add_foreign_key "shop_orders", "users", column: "fufilled_by_id"
  add_foreign_key "shop_orders", "users", column: "on_hold_by_id"
  add_foreign_key "shop_orders", "users", column: "rejected_by_id"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "task_lists", "users"
  add_foreign_key "timeline_items", "projects"
  add_foreign_key "users", "users", column: "referrer_id"
end
