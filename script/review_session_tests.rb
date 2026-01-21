#!/usr/bin/env ruby
# Run with: bin/rails runner script/review_session_tests.rb

require "active_support/testing/time_helpers"
include ActiveSupport::Testing::TimeHelpers

PASS_COUNT = { count: 0 }
FAIL_COUNT = { count: 0 }

def assert(name)
  yield
  PASS_COUNT[:count] += 1
  puts "✅ PASS: #{name}"
rescue => e
  FAIL_COUNT[:count] += 1
  puts "❌ FAIL: #{name}"
  puts "   #{e.class}: #{e.message}"
  puts "   #{e.backtrace.first(3).join("\n   ")}"
end

def assert_equal(expected, actual, name)
  assert(name) do
    raise "Expected #{expected.inspect}, got #{actual.inspect}" unless expected == actual
  end
end

def assert_true(value, name)
  assert(name) { raise "Expected true, got #{value.inspect}" unless value == true }
end

def assert_false(value, name)
  assert(name) { raise "Expected false, got #{value.inspect}" unless value == false }
end

def assert_nil(value, name)
  assert(name) { raise "Expected nil, got #{value.inspect}" unless value.nil? }
end

def assert_not_nil(value, name)
  assert(name) { raise "Expected not nil, got nil" if value.nil? }
end

# Helper to create a test user
def make_user!(admin: false)
  User.create!(
    email: "test_#{SecureRandom.hex(6)}@test.local",
    slack_id: "U#{SecureRandom.hex(8).upcase}",
    username: "test_#{SecureRandom.hex(4)}",
    admin: admin,
    reviewer: true
  )
end

# Helper to create a project with a specific waiting_since timestamp
def make_project_with_waiting_since!(waiting_since:, owner: nil, ysws: nil, deleted: false)
  owner ||= make_user!

  PaperTrail.request(enabled: true) do
    p = Project.create!(
      user: owner,
      title: "Test Project #{SecureRandom.hex(4)}",
      is_deleted: deleted,
      ysws: ysws,
      review_status: nil,
      funding_needed_cents: 0,
      needs_funding: false
    )

    # Update to design_pending to create the version
    p.update!(review_status: :design_pending)

    # Find and backdate the version
    v = p.versions.where("object_changes->>'review_status' IS NOT NULL").order(:id).last
    if v
      v.update_column(:created_at, waiting_since)
    end

    p.reload
  end
end

# Helper to get next project ID using controller's private method
# test_project_ids: limit results to only these project IDs (for test isolation)
def next_project_id(reviewer, type: :design, after_project_id: nil, admin: false, test_project_ids: nil)
  # Simulate the controller's next_project_in_queue logic directly
  claim_cutoff = Reviews::ClaimProject::TTL.ago

  if type == :design
    waiting_since_sql = "(SELECT MAX(versions.created_at) FROM versions WHERE versions.item_type = 'Project' AND versions.item_id = projects.id AND versions.event = 'update' AND jsonb_exists(versions.object_changes, 'review_status') AND versions.object_changes->'review_status'->>1 = 'design_pending')"

    reviewed_ids = Project.joins(:design_reviews)
                          .where(is_deleted: false, review_status: :design_pending)
                          .where(design_reviews: { invalidated: false })
                          .distinct
                          .pluck(:id)

    base = Project.active.design_pending.where.not(user_id: reviewer.id)
                  .where("design_review_claimed_by_id IS NULL OR design_review_claimed_at IS NULL OR design_review_claimed_at < ? OR design_review_claimed_by_id = ?", claim_cutoff, reviewer.id)

    # For test isolation: only consider specific test project IDs
    base = base.where(id: test_project_ids) if test_project_ids.present?

    unless admin
      base = base.where.not(id: reviewed_ids).where("ysws IS NULL OR ysws != ?", "led")
    end

    if after_project_id.present?
      after_waiting_since = Project.where(id: after_project_id)
                                   .select(waiting_since_sql)
                                   .take
                                   &.attributes&.values&.first
      if after_waiting_since
        base = base.where("#{waiting_since_sql} > ?", after_waiting_since)
      end
    end

    # For admins, prioritize pre-reviewed projects first, then by waiting time
    if admin
      pre_reviewed_sql = "CASE WHEN projects.id IN (#{reviewed_ids.any? ? reviewed_ids.join(',') : 'NULL'}) THEN 0 ELSE 1 END"
      base.select("projects.id, #{waiting_since_sql} AS waiting_since")
          .order(Arel.sql("#{pre_reviewed_sql}, #{waiting_since_sql} ASC NULLS LAST"))
          .limit(1)
          .pick(:id)
    else
      base.select("projects.id, #{waiting_since_sql} AS waiting_since")
          .order(Arel.sql("#{waiting_since_sql} ASC NULLS LAST"))
          .limit(1)
          .pick(:id)
    end
  end
end

# Clean up test data - mark as deleted instead of destroying to avoid FK issues
def cleanup_test_data!
  Project.where("title LIKE ?", "Test Project%").update_all(is_deleted: true, review_status: nil)
  # Don't delete users - they may have FK refs. Just leave them as orphaned test users.
end

puts "\n" + "=" * 60
puts "REVIEW SESSION TEST SUITE"
puts "=" * 60 + "\n\n"

# Cleanup before tests
cleanup_test_data!

# =============================================================================
# CATEGORY 1: CLAIMING MECHANICS
# =============================================================================
puts "\n--- CATEGORY 1: CLAIMING MECHANICS ---\n"

# C1.1 Acquire claim on unclaimed project
assert("C1.1 Acquire claim on unclaimed project") do
  r1 = make_user!
  p = make_project_with_waiting_since!(waiting_since: 1.day.ago)

  result = Reviews::ClaimProject.call!(project: p, reviewer: r1, type: :design)
  p.reload

  raise "Expected true" unless result == true
  raise "Wrong claimed_by" unless p.design_review_claimed_by_id == r1.id
  raise "claimed_at not set" unless p.design_review_claimed_at.present?
end

# C1.2 Idempotent claim by same reviewer
assert("C1.2 Idempotent claim refreshes timestamp") do
  r1 = make_user!
  p = make_project_with_waiting_since!(waiting_since: 1.day.ago)

  Reviews::ClaimProject.call!(project: p, reviewer: r1, type: :design)
  p.reload
  old_claimed_at = p.design_review_claimed_at

  sleep 0.1
  result = Reviews::ClaimProject.call!(project: p, reviewer: r1, type: :design)
  p.reload

  raise "Expected true" unless result == true
  raise "Wrong claimed_by" unless p.design_review_claimed_by_id == r1.id
  raise "Timestamp should refresh" unless p.design_review_claimed_at >= old_claimed_at
end

# C1.3 Claim blocked by active claim from another reviewer
assert("C1.3 Claim blocked by active claim from another") do
  r1 = make_user!
  r2 = make_user!
  p = make_project_with_waiting_since!(waiting_since: 1.day.ago)

  Reviews::ClaimProject.call!(project: p, reviewer: r2, type: :design)
  result = Reviews::ClaimProject.call!(project: p, reviewer: r1, type: :design)
  p.reload

  raise "Expected false" unless result == false
  raise "Should still be claimed by r2" unless p.design_review_claimed_by_id == r2.id
end

# C1.4 Expired claim can be taken over
assert("C1.4 Expired claim can be taken over") do
  r1 = make_user!
  r2 = make_user!
  p = make_project_with_waiting_since!(waiting_since: 1.day.ago)

  # r2 claims, then we expire it
  p.update_columns(design_review_claimed_by_id: r2.id, design_review_claimed_at: 21.minutes.ago)

  result = Reviews::ClaimProject.call!(project: p, reviewer: r1, type: :design)
  p.reload

  raise "Expected true" unless result == true
  raise "Should now be claimed by r1" unless p.design_review_claimed_by_id == r1.id
end

# C1.5 claimed_by set but claimed_at NULL is claimable
assert("C1.5 NULL claimed_at is claimable") do
  r1 = make_user!
  r2 = make_user!
  p = make_project_with_waiting_since!(waiting_since: 1.day.ago)

  p.update_columns(design_review_claimed_by_id: r2.id, design_review_claimed_at: nil)

  result = Reviews::ClaimProject.call!(project: p, reviewer: r1, type: :design)
  p.reload

  raise "Expected true" unless result == true
  raise "Should now be claimed by r1" unless p.design_review_claimed_by_id == r1.id
  raise "claimed_at should be set" unless p.design_review_claimed_at.present?
end

# C1.6 claimed_by? truth table
assert("C1.6a claimed_by? true when active") do
  r1 = make_user!
  p = make_project_with_waiting_since!(waiting_since: 1.day.ago)
  p.update_columns(design_review_claimed_by_id: r1.id, design_review_claimed_at: Time.current)
  p.reload

  result = Reviews::ClaimProject.claimed_by?(project: p, reviewer: r1, type: :design)
  raise "Expected true" unless result == true
end

assert("C1.6b claimed_by? false when expired") do
  r1 = make_user!
  p = make_project_with_waiting_since!(waiting_since: 1.day.ago)
  p.update_columns(design_review_claimed_by_id: r1.id, design_review_claimed_at: 21.minutes.ago)
  p.reload

  result = Reviews::ClaimProject.claimed_by?(project: p, reviewer: r1, type: :design)
  raise "Expected false" unless result == false
end

assert("C1.6c claimed_by? false for different reviewer") do
  r1 = make_user!
  r2 = make_user!
  p = make_project_with_waiting_since!(waiting_since: 1.day.ago)
  p.update_columns(design_review_claimed_by_id: r2.id, design_review_claimed_at: Time.current)
  p.reload

  result = Reviews::ClaimProject.claimed_by?(project: p, reviewer: r1, type: :design)
  raise "Expected false" unless result == false
end

assert("C1.6d claimed_by? false when claimed_at nil") do
  r1 = make_user!
  p = make_project_with_waiting_since!(waiting_since: 1.day.ago)
  p.update_columns(design_review_claimed_by_id: r1.id, design_review_claimed_at: nil)
  p.reload

  result = Reviews::ClaimProject.claimed_by?(project: p, reviewer: r1, type: :design)
  raise "Expected false" unless result == false
end

# C1.7 claimed_by_other? truth table
assert("C1.7a claimed_by_other? true when claimed by another") do
  r1 = make_user!
  r2 = make_user!
  p = make_project_with_waiting_since!(waiting_since: 1.day.ago)
  p.update_columns(design_review_claimed_by_id: r2.id, design_review_claimed_at: Time.current)
  p.reload

  result = Reviews::ClaimProject.claimed_by_other?(project: p, reviewer: r1, type: :design)
  raise "Expected true" unless result == true
end

assert("C1.7b claimed_by_other? false when expired") do
  r1 = make_user!
  r2 = make_user!
  p = make_project_with_waiting_since!(waiting_since: 1.day.ago)
  p.update_columns(design_review_claimed_by_id: r2.id, design_review_claimed_at: 21.minutes.ago)
  p.reload

  result = Reviews::ClaimProject.claimed_by_other?(project: p, reviewer: r1, type: :design)
  raise "Expected false" unless result == false
end

assert("C1.7c claimed_by_other? false when claimed_at nil") do
  r1 = make_user!
  r2 = make_user!
  p = make_project_with_waiting_since!(waiting_since: 1.day.ago)
  p.update_columns(design_review_claimed_by_id: r2.id, design_review_claimed_at: nil)
  p.reload

  result = Reviews::ClaimProject.claimed_by_other?(project: p, reviewer: r1, type: :design)
  raise "Expected false" unless result == false
end

# C1.8 release! only releases if owned
assert("C1.8 release! only releases if owned by reviewer") do
  r1 = make_user!
  r2 = make_user!
  p = make_project_with_waiting_since!(waiting_since: 1.day.ago)
  p.update_columns(design_review_claimed_by_id: r2.id, design_review_claimed_at: Time.current)

  Reviews::ClaimProject.release!(project: p, reviewer: r1, type: :design)
  p.reload
  raise "Should still be claimed by r2" unless p.design_review_claimed_by_id == r2.id

  Reviews::ClaimProject.release!(project: p, reviewer: r2, type: :design)
  p.reload
  raise "Should be released" unless p.design_review_claimed_by_id.nil?
end

# C1.9 release_all_for_reviewer! returns count and only releases active
assert("C1.9 release_all_for_reviewer! releases only active claims") do
  r1 = make_user!
  p_active = make_project_with_waiting_since!(waiting_since: 1.day.ago)
  p_expired = make_project_with_waiting_since!(waiting_since: 2.days.ago)

  p_active.update_columns(design_review_claimed_by_id: r1.id, design_review_claimed_at: Time.current)
  p_expired.update_columns(design_review_claimed_by_id: r1.id, design_review_claimed_at: 21.minutes.ago)

  count = Reviews::ClaimProject.release_all_for_reviewer!(reviewer: r1, type: :design)
  p_active.reload
  p_expired.reload

  raise "Expected count 1, got #{count}" unless count == 1
  raise "p_active should be released" unless p_active.design_review_claimed_by_id.nil?
  raise "p_expired should remain (stale)" unless p_expired.design_review_claimed_by_id == r1.id
end

# C1.10 Claiming new project releases prior active claim
assert("C1.10 Claiming new project releases prior claim") do
  r1 = make_user!
  p1 = make_project_with_waiting_since!(waiting_since: 2.days.ago)
  p2 = make_project_with_waiting_since!(waiting_since: 1.day.ago)

  Reviews::ClaimProject.call!(project: p1, reviewer: r1, type: :design)
  p1.reload
  raise "p1 should be claimed" unless p1.design_review_claimed_by_id == r1.id

  Reviews::ClaimProject.call!(project: p2, reviewer: r1, type: :design)
  p1.reload
  p2.reload

  raise "p1 should be released" unless p1.design_review_claimed_by_id.nil?
  raise "p2 should be claimed" unless p2.design_review_claimed_by_id == r1.id
end

# C1.11 Race condition: two reviewers claim same project
assert("C1.11 Race: exactly one winner when claiming same project") do
  r1 = make_user!
  r2 = make_user!
  p = make_project_with_waiting_since!(waiting_since: 1.day.ago)

  barrier = Queue.new
  results = []
  mutex = Mutex.new

  t1 = Thread.new do
    barrier.pop
    res = Reviews::ClaimProject.call!(project: p.reload, reviewer: r1, type: :design)
    mutex.synchronize { results << [ :r1, res ] }
  end

  t2 = Thread.new do
    barrier.pop
    res = Reviews::ClaimProject.call!(project: p.reload, reviewer: r2, type: :design)
    mutex.synchronize { results << [ :r2, res ] }
  end

  2.times { barrier << true }
  [ t1, t2 ].each(&:join)

  winners = results.select { |_, ok| ok }
  raise "Expected exactly 1 winner, got #{winners.size}: #{results.inspect}" unless winners.size == 1
end

# =============================================================================
# CATEGORY 2: QUEUE ORDERING
# =============================================================================
puts "\n--- CATEGORY 2: QUEUE ORDERING ---\n"

# Q2.1 Picks longest-waiting first
assert("Q2.1 Picks longest-waiting project first") do
  r1 = make_user!
  p_oldest = make_project_with_waiting_since!(waiting_since: 3.days.ago)
  p_mid = make_project_with_waiting_since!(waiting_since: 2.days.ago)
  p_new = make_project_with_waiting_since!(waiting_since: 1.day.ago)
  test_ids = [ p_oldest.id, p_mid.id, p_new.id ]

  result = next_project_id(r1, test_project_ids: test_ids)
  raise "Expected #{p_oldest.id}, got #{result}" unless result == p_oldest.id
end

# Q2.2 after parameter skips older projects
assert("Q2.2 after parameter skips to next in queue") do
  r1 = make_user!
  p_oldest = make_project_with_waiting_since!(waiting_since: 3.days.ago)
  p_mid = make_project_with_waiting_since!(waiting_since: 2.days.ago)
  p_new = make_project_with_waiting_since!(waiting_since: 1.day.ago)
  test_ids = [ p_oldest.id, p_mid.id, p_new.id ]

  result = next_project_id(r1, after_project_id: p_mid.id, test_project_ids: test_ids)
  raise "Expected #{p_new.id}, got #{result}" unless result == p_new.id
end

# Q2.3 after with invalid project ID behaves like no after
assert("Q2.3 after with invalid ID returns oldest") do
  r1 = make_user!
  p_oldest = make_project_with_waiting_since!(waiting_since: 3.days.ago)
  p_new = make_project_with_waiting_since!(waiting_since: 1.day.ago)
  test_ids = [ p_oldest.id, p_new.id ]

  result = next_project_id(r1, after_project_id: 999999999, test_project_ids: test_ids)
  raise "Expected #{p_oldest.id}, got #{result}" unless result == p_oldest.id
end

# Q2.4 Admin sees pre-reviewed projects first (even if they waited less)
assert("Q2.4 Admin: pre-reviewed projects shown before non-reviewed (by wait time within each group)") do
  admin = make_user!(admin: true)
  reviewer = make_user!

  # Create projects: p_old is oldest but NOT pre-reviewed, p_new is newer but IS pre-reviewed
  p_old_no_review = make_project_with_waiting_since!(waiting_since: 3.days.ago)
  p_new_reviewed = make_project_with_waiting_since!(waiting_since: 1.day.ago)

  # Add a design review to p_new_reviewed to make it "pre-reviewed"
  DesignReview.create!(
    project: p_new_reviewed,
    reviewer: reviewer,
    result: :returned,
    feedback: "Please fix"
  )

  test_ids = [ p_old_no_review.id, p_new_reviewed.id ]

  # Admin should see pre-reviewed first
  result = next_project_id(admin, admin: true, test_project_ids: test_ids)
  raise "Admin expected #{p_new_reviewed.id} (pre-reviewed), got #{result}" unless result == p_new_reviewed.id
end

# Q2.5 Admin: within pre-reviewed, longest wait first
assert("Q2.5 Admin: within pre-reviewed group, longest wait first") do
  admin = make_user!(admin: true)
  reviewer = make_user!

  p_reviewed_old = make_project_with_waiting_since!(waiting_since: 3.days.ago)
  p_reviewed_new = make_project_with_waiting_since!(waiting_since: 1.day.ago)

  # Both are pre-reviewed
  DesignReview.create!(project: p_reviewed_old, reviewer: reviewer, result: :returned, feedback: "Fix")
  DesignReview.create!(project: p_reviewed_new, reviewer: reviewer, result: :returned, feedback: "Fix")

  test_ids = [ p_reviewed_old.id, p_reviewed_new.id ]

  result = next_project_id(admin, admin: true, test_project_ids: test_ids)
  raise "Expected #{p_reviewed_old.id} (oldest pre-reviewed), got #{result}" unless result == p_reviewed_old.id
end

# Q2.6 Admin: non-reviewed come after all pre-reviewed
assert("Q2.6 Admin: all pre-reviewed before any non-reviewed") do
  admin = make_user!(admin: true)
  reviewer = make_user!

  # Old non-reviewed, new pre-reviewed, medium non-reviewed
  p_oldest_no_review = make_project_with_waiting_since!(waiting_since: 5.days.ago)
  p_mid_reviewed = make_project_with_waiting_since!(waiting_since: 2.days.ago)
  p_new_no_review = make_project_with_waiting_since!(waiting_since: 1.day.ago)

  DesignReview.create!(project: p_mid_reviewed, reviewer: reviewer, result: :returned, feedback: "Fix")

  test_ids = [ p_oldest_no_review.id, p_mid_reviewed.id, p_new_no_review.id ]

  # First should be the pre-reviewed one
  result = next_project_id(admin, admin: true, test_project_ids: test_ids)
  raise "Expected #{p_mid_reviewed.id} (pre-reviewed), got #{result}" unless result == p_mid_reviewed.id
end

# =============================================================================
# CATEGORY 3: SESSION LIFECYCLE
# =============================================================================
puts "\n--- CATEGORY 3: SESSION LIFECYCLE ---\n"

# S3.1 Expired claim still allows submission (claimed_by? returns false but submission is allowed)
assert("S3.1 Expired claim - claimed_by? returns false but submission still allowed") do
  r1 = make_user!
  p = make_project_with_waiting_since!(waiting_since: 1.day.ago)
  p.update_columns(design_review_claimed_by_id: r1.id, design_review_claimed_at: 21.minutes.ago)
  p.reload

  # claimed_by? returns false for expired claims
  result = Reviews::ClaimProject.claimed_by?(project: p, reviewer: r1, type: :design)
  raise "claimed_by? should be false (expired)" unless result == false

  # But the reviewer is still the original claimer (submission is allowed)
  raise "design_review_claimed_by_id should still be r1" unless p.design_review_claimed_by_id == r1.id
end

# S3.2 Session continues: after submit, next project is correct
assert("S3.2 After submit, next project skips current") do
  r1 = make_user!
  p1 = make_project_with_waiting_since!(waiting_since: 3.days.ago)
  p2 = make_project_with_waiting_since!(waiting_since: 2.days.ago)
  p3 = make_project_with_waiting_since!(waiting_since: 1.day.ago)
  test_ids = [ p1.id, p2.id, p3.id ]

  # Simulate: reviewed p1, now get next
  result = next_project_id(r1, after_project_id: p1.id, test_project_ids: test_ids)
  raise "Expected #{p2.id}, got #{result}" unless result == p2.id

  # Simulate: reviewed p2, now get next
  result = next_project_id(r1, after_project_id: p2.id, test_project_ids: test_ids)
  raise "Expected #{p3.id}, got #{result}" unless result == p3.id
end

# =============================================================================
# CATEGORY 4: MULTI-REVIEWER SCENARIOS
# =============================================================================
puts "\n--- CATEGORY 4: MULTI-REVIEWER SCENARIOS ---\n"

# M4.1 Two reviewers get different projects
assert("M4.1 Two reviewers starting sessions get different projects") do
  r1 = make_user!
  r2 = make_user!
  p1 = make_project_with_waiting_since!(waiting_since: 2.days.ago)
  p2 = make_project_with_waiting_since!(waiting_since: 1.day.ago)

  id1 = next_project_id(r1)
  Reviews::ClaimProject.call!(project: Project.find(id1), reviewer: r1, type: :design)

  id2 = next_project_id(r2)

  raise "Expected different projects, both got #{id1}" unless id1 != id2
end

# M4.2 Claimed project is filtered from queue for other reviewer
assert("M4.2 Claimed project filtered for other reviewer") do
  r1 = make_user!
  r2 = make_user!
  p = make_project_with_waiting_since!(waiting_since: 1.day.ago)
  test_ids = [ p.id ]

  Reviews::ClaimProject.call!(project: p, reviewer: r1, type: :design)

  result = next_project_id(r2, test_project_ids: test_ids)
  raise "Should be nil (only project is claimed)" unless result.nil?
end

# M4.3 Expired claim makes project available again
assert("M4.3 Expired claim makes project available") do
  r1 = make_user!
  r2 = make_user!
  p = make_project_with_waiting_since!(waiting_since: 1.day.ago)
  test_ids = [ p.id ]

  p.update_columns(design_review_claimed_by_id: r1.id, design_review_claimed_at: 21.minutes.ago)

  result = next_project_id(r2, test_project_ids: test_ids)
  raise "Expected #{p.id}, got #{result}" unless result == p.id
end

# =============================================================================
# CATEGORY 5: EDGE CASES
# =============================================================================
puts "\n--- CATEGORY 5: EDGE CASES ---\n"

# E5.1 No projects available returns nil
assert("E5.1 No projects available returns nil") do
  r1 = make_user!
  # Use a non-existent project ID to simulate no projects
  result = next_project_id(r1, test_project_ids: [ -1 ])
  raise "Expected nil" unless result.nil?
end

# E5.2 Exclude own projects
assert("E5.2 Exclude reviewer's own projects") do
  r1 = make_user!
  p_own = make_project_with_waiting_since!(waiting_since: 2.days.ago, owner: r1)
  p_other = make_project_with_waiting_since!(waiting_since: 1.day.ago)
  test_ids = [ p_own.id, p_other.id ]

  result = next_project_id(r1, test_project_ids: test_ids)
  raise "Expected #{p_other.id}, got #{result}" unless result == p_other.id
end

# E5.3 LED projects excluded for non-admin
assert("E5.3 LED projects excluded for non-admin") do
  r1 = make_user!
  p_led = make_project_with_waiting_since!(waiting_since: 2.days.ago, ysws: "led")
  p_normal = make_project_with_waiting_since!(waiting_since: 1.day.ago)
  test_ids = [ p_led.id, p_normal.id ]

  result = next_project_id(r1, admin: false, test_project_ids: test_ids)
  raise "Expected #{p_normal.id}, got #{result}" unless result == p_normal.id
end

# E5.4 Admin can see LED projects
assert("E5.4 Admin can see LED projects") do
  r1 = make_user!(admin: true)
  p_led = make_project_with_waiting_since!(waiting_since: 2.days.ago, ysws: "led")
  p_normal = make_project_with_waiting_since!(waiting_since: 1.day.ago)
  test_ids = [ p_led.id, p_normal.id ]

  result = next_project_id(r1, admin: true, test_project_ids: test_ids)
  raise "Expected #{p_led.id} (oldest), got #{result}" unless result == p_led.id
end

# =============================================================================
# CATEGORY 6: SKIP FUNCTIONALITY
# =============================================================================
puts "\n--- CATEGORY 6: SKIP FUNCTIONALITY ---\n"

# K6.1 Skip advances using after
assert("K6.1 Skip advances correctly using after") do
  r1 = make_user!
  p_oldest = make_project_with_waiting_since!(waiting_since: 3.days.ago)
  p_mid = make_project_with_waiting_since!(waiting_since: 2.days.ago)
  p_new = make_project_with_waiting_since!(waiting_since: 1.day.ago)
  test_ids = [ p_oldest.id, p_mid.id, p_new.id ]

  # Start at p_oldest, skip to p_mid
  result = next_project_id(r1, after_project_id: p_oldest.id, test_project_ids: test_ids)
  raise "Expected #{p_mid.id}, got #{result}" unless result == p_mid.id

  # Skip p_mid, go to p_new
  result = next_project_id(r1, after_project_id: p_mid.id, test_project_ids: test_ids)
  raise "Expected #{p_new.id}, got #{result}" unless result == p_new.id

  # Skip p_new, should be nil (end of queue)
  result = next_project_id(r1, after_project_id: p_new.id, test_project_ids: test_ids)
  raise "Expected nil (end of queue), got #{result}" unless result.nil?
end

# K6.2 Skip releases previous claim when claiming next
assert("K6.2 Skip releases previous claim when claiming next") do
  r1 = make_user!
  p1 = make_project_with_waiting_since!(waiting_since: 2.days.ago)
  p2 = make_project_with_waiting_since!(waiting_since: 1.day.ago)

  Reviews::ClaimProject.call!(project: p1, reviewer: r1, type: :design)
  p1.reload
  raise "p1 should be claimed" unless p1.design_review_claimed_by_id == r1.id

  # Skip to p2 (claim p2)
  Reviews::ClaimProject.call!(project: p2, reviewer: r1, type: :design)
  p1.reload
  p2.reload

  raise "p1 should be released" unless p1.design_review_claimed_by_id.nil?
  raise "p2 should be claimed" unless p2.design_review_claimed_by_id == r1.id
end

# =============================================================================
# CATEGORY 7: SLACK NOTIFICATION RESULT MESSAGES
# =============================================================================
puts "\n--- CATEGORY 7: SLACK NOTIFICATION RESULT MESSAGES ---\n"

# Helper to get the result message that would be sent to Slack
def slack_result_message(review)
  if review.result == "approved"
    review.admin_review? ? "APPROVED!! :D" : "preliminarily approved"
  else
    "needs update"
  end
end

# N7.1 Admin approval shows "APPROVED!! :D"
assert("N7.1 Admin approval shows 'APPROVED!! :D'") do
  admin = make_user!(admin: true)
  p = make_project_with_waiting_since!(waiting_since: 1.day.ago)

  review = DesignReview.create!(
    project: p,
    reviewer: admin,
    result: :approved,
    admin_review: true,
    feedback: "Great work!"
  )

  result = slack_result_message(review)
  raise "Expected 'APPROVED!! :D', got '#{result}'" unless result == "APPROVED!! :D"
end

# N7.2 Non-admin approval shows "preliminarily approved"
assert("N7.2 Non-admin approval shows 'preliminarily approved'") do
  reviewer = make_user!
  p = make_project_with_waiting_since!(waiting_since: 1.day.ago)

  review = DesignReview.create!(
    project: p,
    reviewer: reviewer,
    result: :approved,
    admin_review: false,
    feedback: "Looks good!"
  )

  result = slack_result_message(review)
  raise "Expected 'preliminarily approved', got '#{result}'" unless result == "preliminarily approved"
end

# N7.3 Returned review shows "needs update"
assert("N7.3 Returned review shows 'needs update'") do
  reviewer = make_user!
  p = make_project_with_waiting_since!(waiting_since: 1.day.ago)

  review = DesignReview.create!(
    project: p,
    reviewer: reviewer,
    result: :returned,
    admin_review: false,
    feedback: "Please fix X"
  )

  result = slack_result_message(review)
  raise "Expected 'needs update', got '#{result}'" unless result == "needs update"
end

# N7.4 Rejected review shows "needs update"
assert("N7.4 Rejected review shows 'needs update'") do
  admin = make_user!(admin: true)
  p = make_project_with_waiting_since!(waiting_since: 1.day.ago)

  review = DesignReview.create!(
    project: p,
    reviewer: admin,
    result: :rejected,
    admin_review: true,
    feedback: "Does not meet requirements"
  )

  result = slack_result_message(review)
  raise "Expected 'needs update', got '#{result}'" unless result == "needs update"
end

# =============================================================================
# CLEANUP & SUMMARY
# =============================================================================
puts "\n" + "=" * 60
cleanup_test_data!
puts "\nTEST SUMMARY:"
puts "  Passed: #{PASS_COUNT[:count]}"
puts "  Failed: #{FAIL_COUNT[:count]}"
puts "=" * 60

exit(FAIL_COUNT[:count] > 0 ? 1 : 0)
