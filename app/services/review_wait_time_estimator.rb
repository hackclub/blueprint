# frozen_string_literal: true

class ReviewWaitTimeEstimator
  VALID_PENDING_STATUSES = %w[design_pending build_pending].freeze
  MIN_YSWS_SAMPLES = 100
  THROUGHPUT_WINDOW_DAYS = 28
  CACHE_EXPIRY = 1.day

  attr_reader :pending_status

  def initialize(pending_status:)
    unless VALID_PENDING_STATUSES.include?(pending_status.to_s)
      raise ArgumentError, "pending_status must be one of: #{VALID_PENDING_STATUSES.join(', ')}"
    end

    @pending_status = pending_status.to_s
  end

  def eta_for_new_submission(ysws:, tier:)
    stats = queue_stats
    bucket = determine_bucket(ysws: ysws, tier: tier, stats: stats)

    work_ahead = stats[:work_ahead_by_bucket][bucket] || 0
    work_unit = work_unit_for(ysws: ysws, tier: tier, stats: stats)
    effective_throughput = stats[:effective_by_bucket][bucket] || stats[:effective_throughput]

    eta_seconds = ((work_ahead + work_unit) / effective_throughput) * 1.day.to_i
    eta_seconds = [ eta_seconds, 1.day.to_i ].max

    bucket_pending = stats[:pending_by_bucket][bucket]&.size || 0

    {
      eta_seconds: eta_seconds.to_i,
      eta_days: (eta_seconds / 1.day.to_f).round(1),
      queue_length: bucket_pending,
      total_queue_length: stats[:pending_count],
      effective_throughput_per_day: effective_throughput.round(2),
      source: bucket
    }
  end

  def remaining_for_project(project:)
    stats = queue_stats
    position_info = queue_position_for(project: project, stats: stats)

    return nil unless position_info

    bucket = position_info[:bucket]
    work_ahead = position_info[:work_ahead]
    my_work = position_info[:my_work]
    effective_throughput = stats[:effective_by_bucket][bucket] || stats[:effective_throughput]

    eta_seconds = ((work_ahead + my_work) / effective_throughput) * 1.day.to_i
    eta_seconds = [ eta_seconds, 1.day.to_i ].max
    already_waited = position_info[:already_waited_seconds]

    bucket_pending = stats[:pending_by_bucket][bucket]&.size || 0

    {
      eta_seconds: eta_seconds.to_i,
      eta_days: (eta_seconds / 1.day.to_f).round(1),
      already_waited_seconds: already_waited,
      already_waited_days: (already_waited / 1.day.to_f).round(1),
      position: position_info[:position],
      queue_length: bucket_pending,
      total_queue_length: stats[:pending_count],
      effective_throughput_per_day: effective_throughput.round(2),
      source: bucket
    }
  end

  def queue_stats
    Rails.cache.fetch(cache_key("queue_stats"), expires_in: CACHE_EXPIRY, race_condition_ttl: 30.seconds) do
      build_queue_stats
    end
  end

  private

  def cache_key(suffix)
    "review_wait_time_estimator/v2/#{pending_status}/#{suffix}"
  end

  def build_queue_stats
    historical = historical_stats
    pending = pending_projects_with_ages

    pending_by_bucket = pending.group_by { |p| bucket_for_project(p, historical) }

    observed_by_bucket = calculate_observed_throughput_by_bucket
    age_bound_by_bucket = {}
    effective_by_bucket = {}
    work_ahead_by_bucket = {}

    pending_by_bucket.each do |bucket, projects|
      age_bound_by_bucket[bucket] = calculate_age_bound_throughput(projects)

      observed = observed_by_bucket[bucket] || 0.1
      effective_by_bucket[bucket] = observed > 0 ? observed : 0.1

      work_ahead_by_bucket[bucket] = projects.sum do |p|
        work_unit_for(ysws: p[:ysws], tier: p[:tier], stats: { historical: historical })
      end
    end

    global_observed = calculate_observed_throughput
    global_age_bound = calculate_age_bound_throughput(pending)
    global_effective = [ global_observed, global_age_bound ].compact.min
    global_effective = 0.1 if global_effective <= 0

    {
      historical: historical,
      pending_count: pending.size,
      pending_by_bucket: pending_by_bucket,
      observed_throughput: global_observed,
      age_bound_throughput: global_age_bound,
      effective_throughput: global_effective,
      observed_by_bucket: observed_by_bucket,
      age_bound_by_bucket: age_bound_by_bucket,
      effective_by_bucket: effective_by_bucket,
      work_ahead_by_bucket: work_ahead_by_bucket,
      pending_projects: pending
    }
  end

  def bucket_for_project(project, historical)
    ysws = project[:ysws]
    tier = project[:tier]

    if ysws.present? && historical[:ysws]&.key?(ysws)
      "ysws:#{ysws}"
    elsif tier.present?
      "tier:#{tier}"
    else
      "global"
    end
  end

  def determine_bucket(ysws:, tier:, stats:)
    historical = stats[:historical]

    if ysws.present? && historical[:ysws]&.key?(ysws)
      "ysws:#{ysws}"
    elsif tier.present?
      "tier:#{tier}"
    else
      "global"
    end
  end

  def historical_stats
    Rails.cache.fetch(cache_key("historical_stats"), expires_in: CACHE_EXPIRY, race_condition_ttl: 30.seconds) do
      build_historical_stats
    end
  end

  def build_historical_stats
    rows = ActiveRecord::Base.connection.select_all(historical_sql).to_a

    ysws_stats = {}
    tier_stats = {}
    global_median = 0.0
    global_count = 0

    rows.each do |row|
      case row["bucket_type"]
      when "ysws"
        ysws_stats[row["bucket_key"]] = {
          median_seconds: row["median_seconds"].to_f,
          sample_count: row["sample_count"].to_i
        }
      when "tier"
        tier_stats[row["bucket_key"]] = {
          median_seconds: row["median_seconds"].to_f,
          sample_count: row["sample_count"].to_i
        }
      when "global"
        global_median = row["median_seconds"].to_f
        global_count = row["sample_count"].to_i
      end
    end

    valid_ysws = ysws_stats.select { |_, v| v[:sample_count] >= MIN_YSWS_SAMPLES }

    {
      ysws: valid_ysws,
      tier: tier_stats,
      global_median: global_median,
      global_count: global_count
    }
  end

  def historical_sql
    <<~SQL
      WITH status_changes AS (
        SELECT
          item_id AS project_id,
          created_at,
          id,
          object_changes->'review_status'->>0 AS before_status,
          object_changes->'review_status'->>1 AS after_status
        FROM versions
        WHERE item_type = 'Project'
          AND event = 'update'
          AND (object_changes ? 'review_status')
      ),
      status_changes_with_next AS (
        SELECT
          project_id,
          created_at,
          after_status,
          LEAD(created_at) OVER w AS next_at,
          LEAD(before_status) OVER w AS next_before_status,
          LEAD(after_status) OVER w AS next_after_status
        FROM status_changes
        WINDOW w AS (PARTITION BY project_id ORDER BY created_at, id)
      ),
      completed_windows AS (
        SELECT
          sc.project_id,
          p.ysws,
          p.tier,
          EXTRACT(EPOCH FROM (sc.next_at - sc.created_at))::bigint AS wait_seconds
        FROM status_changes_with_next sc
        JOIN projects p ON p.id = sc.project_id
        WHERE sc.after_status = #{ActiveRecord::Base.connection.quote(pending_status)}
          AND sc.next_at IS NOT NULL
          AND sc.next_before_status = #{ActiveRecord::Base.connection.quote(pending_status)}
          AND sc.next_after_status IS DISTINCT FROM #{ActiveRecord::Base.connection.quote(pending_status)}
          AND sc.next_at >= sc.created_at
          AND sc.next_at >= NOW() - INTERVAL '180 days'
          AND p.is_deleted = FALSE
      ),
      ysws_stats AS (
        SELECT
          'ysws' AS bucket_type,
          ysws AS bucket_key,
          COUNT(*) AS sample_count,
          percentile_cont(0.5) WITHIN GROUP (ORDER BY wait_seconds) AS median_seconds
        FROM completed_windows
        WHERE ysws IS NOT NULL
        GROUP BY ysws
      ),
      tier_stats AS (
        SELECT
          'tier' AS bucket_type,
          tier::text AS bucket_key,
          COUNT(*) AS sample_count,
          percentile_cont(0.5) WITHIN GROUP (ORDER BY wait_seconds) AS median_seconds
        FROM completed_windows
        WHERE tier IS NOT NULL
        GROUP BY tier
      ),
      global_stats AS (
        SELECT
          'global' AS bucket_type,
          'global' AS bucket_key,
          COUNT(*) AS sample_count,
          percentile_cont(0.5) WITHIN GROUP (ORDER BY wait_seconds) AS median_seconds
        FROM completed_windows
      )
      SELECT * FROM ysws_stats
      UNION ALL
      SELECT * FROM tier_stats
      UNION ALL
      SELECT * FROM global_stats
    SQL
  end

  def calculate_observed_throughput
    sql = <<~SQL
      WITH status_changes AS (
        SELECT
          item_id AS project_id,
          created_at,
          object_changes->'review_status'->>0 AS before_status,
          object_changes->'review_status'->>1 AS after_status
        FROM versions
        WHERE item_type = 'Project'
          AND event = 'update'
          AND (object_changes ? 'review_status')
          AND created_at >= NOW() - INTERVAL '#{THROUGHPUT_WINDOW_DAYS} days'
      )
      SELECT COUNT(*) AS completions
      FROM status_changes
      WHERE before_status = #{ActiveRecord::Base.connection.quote(pending_status)}
        AND after_status IS DISTINCT FROM #{ActiveRecord::Base.connection.quote(pending_status)}
    SQL

    completions = ActiveRecord::Base.connection.select_value(sql).to_i
    completions.to_f / THROUGHPUT_WINDOW_DAYS
  end

  def calculate_observed_throughput_by_bucket
    historical = historical_stats
    valid_ysws = historical[:ysws].keys

    sql = <<~SQL
      WITH status_changes AS (
        SELECT
          v.item_id AS project_id,
          v.created_at,
          v.object_changes->'review_status'->>0 AS before_status,
          v.object_changes->'review_status'->>1 AS after_status,
          p.ysws,
          p.tier
        FROM versions v
        JOIN projects p ON p.id = v.item_id
        WHERE v.item_type = 'Project'
          AND v.event = 'update'
          AND (v.object_changes ? 'review_status')
          AND v.created_at >= NOW() - INTERVAL '#{THROUGHPUT_WINDOW_DAYS} days'
          AND p.is_deleted = FALSE
      )
      SELECT ysws, tier, COUNT(*) AS completions
      FROM status_changes
      WHERE before_status = #{ActiveRecord::Base.connection.quote(pending_status)}
        AND after_status IS DISTINCT FROM #{ActiveRecord::Base.connection.quote(pending_status)}
      GROUP BY ysws, tier
    SQL

    rows = ActiveRecord::Base.connection.select_all(sql).to_a
    result = {}

    rows.each do |row|
      ysws = row["ysws"]
      tier = row["tier"]
      completions = row["completions"].to_i

      bucket = if ysws.present? && valid_ysws.include?(ysws)
        "ysws:#{ysws}"
      elsif tier.present?
        "tier:#{tier}"
      else
        "global"
      end

      result[bucket] ||= 0
      result[bucket] += completions.to_f / THROUGHPUT_WINDOW_DAYS
    end

    result
  end

  def calculate_age_bound_throughput(pending_projects)
    return nil if pending_projects.empty?

    # Exclude extreme outliers (>30 days) as they're likely stuck/special cases
    max_age_for_calculation = 30.days.to_i
    normal_pending = pending_projects.reject { |p| p[:age_seconds] > max_age_for_calculation }

    return nil if normal_pending.empty?

    oldest_10_pct = [ (normal_pending.size * 0.1).ceil, 5 ].max
    oldest_ages = normal_pending.map { |p| p[:age_seconds] }.sort.last(oldest_10_pct)
    median_oldest_age_days = oldest_ages[oldest_ages.size / 2].to_f / 1.day.to_i

    return nil if median_oldest_age_days <= 0

    oldest_10_pct.to_f / median_oldest_age_days
  end

  def pending_projects_with_ages
    pending = Project.where(review_status: pending_status.to_sym, is_deleted: false).pluck(:id, :ysws, :tier)

    return [] if pending.empty?

    project_ids = pending.map(&:first)

    ages_sql = <<~SQL
      SELECT DISTINCT ON (item_id)
        item_id AS project_id,
        created_at AS entered_at
      FROM versions
      WHERE item_type = 'Project'
        AND item_id IN (#{project_ids.join(',')})
        AND event = 'update'
        AND (object_changes ? 'review_status')
        AND object_changes->'review_status'->>1 = #{ActiveRecord::Base.connection.quote(pending_status)}
      ORDER BY item_id, created_at DESC
    SQL

    ages = ActiveRecord::Base.connection.select_all(ages_sql).to_a
    ages_by_id = ages.index_by { |r| r["project_id"] }

    now = Time.current
    pending.filter_map do |id, ysws, tier|
      age_row = ages_by_id[id]
      next unless age_row

      entered_at = age_row["entered_at"].to_time
      {
        id: id,
        ysws: ysws,
        tier: tier,
        entered_at: entered_at,
        age_seconds: (now - entered_at).to_i
      }
    end.sort_by { |p| p[:entered_at] }
  end

  def work_unit_for(ysws:, tier:, stats: nil)
    stats ||= queue_stats
    historical = stats[:historical]

    global_median = historical[:global_median]
    return 1.0 if global_median <= 0

    bucket = ysws_bucket(ysws, stats)

    if bucket != "other" && historical[:ysws][bucket]
      return historical[:ysws][bucket][:median_seconds] / global_median
    end

    if tier.present? && historical[:tier][tier.to_s]
      return historical[:tier][tier.to_s][:median_seconds] / global_median
    end

    1.0
  end

  def ysws_bucket(ysws, stats)
    return "other" if ysws.blank?

    historical = stats.is_a?(Hash) && stats[:historical] ? stats[:historical] : stats
    historical = historical[:historical] if historical[:historical]

    if historical[:ysws]&.key?(ysws)
      ysws
    else
      "other"
    end
  end

  def queue_position_for(project:, stats:)
    project_entry = stats[:pending_projects].find { |p| p[:id] == project.id }

    return nil unless project_entry

    bucket = bucket_for_project(project_entry, stats[:historical])
    bucket_projects = stats[:pending_by_bucket][bucket] || []

    position = bucket_projects.index { |p| p[:id] == project.id } || 0
    projects_ahead = bucket_projects.first(position)

    work_ahead = projects_ahead.sum do |p|
      work_unit_for(ysws: p[:ysws], tier: p[:tier], stats: stats)
    end

    my_work = work_unit_for(ysws: project_entry[:ysws], tier: project_entry[:tier], stats: stats)

    {
      position: position + 1,
      bucket: bucket,
      work_ahead: work_ahead,
      my_work: my_work,
      already_waited_seconds: project_entry[:age_seconds]
    }
  end
end
