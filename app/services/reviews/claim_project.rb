class Reviews::ClaimProject
  TTL = 20.minutes

  def self.call!(project:, reviewer:, type:)
    type = type.to_sym
    raise ArgumentError, "type must be :design or :build" unless %i[design build].include?(type)

    cutoff = TTL.ago

    Project.transaction do
      # Release any prior claim this reviewer has for this type
      release_all_for_reviewer!(reviewer: reviewer, type: type)

      # Attempt to claim if unclaimed, expired, or already ours
      # Include claimed_at IS NULL to handle edge case where claimed_by is set but claimed_at is nil
      if type == :design
        updated = Project
          .where(id: project.id)
          .where("design_review_claimed_by_id IS NULL OR design_review_claimed_at IS NULL OR design_review_claimed_at < ? OR design_review_claimed_by_id = ?", cutoff, reviewer.id)
          .update_all(design_review_claimed_by_id: reviewer.id, design_review_claimed_at: Time.current)
      else
        updated = Project
          .where(id: project.id)
          .where("build_review_claimed_by_id IS NULL OR build_review_claimed_at IS NULL OR build_review_claimed_at < ? OR build_review_claimed_by_id = ?", cutoff, reviewer.id)
          .update_all(build_review_claimed_by_id: reviewer.id, build_review_claimed_at: Time.current)
      end

      updated == 1
    end
  end

  def self.release!(project:, reviewer:, type:)
    type = type.to_sym
    raise ArgumentError, "type must be :design or :build" unless %i[design build].include?(type)

    if type == :design
      Project.where(id: project.id, design_review_claimed_by_id: reviewer.id)
             .update_all(design_review_claimed_by_id: nil, design_review_claimed_at: nil)
    else
      Project.where(id: project.id, build_review_claimed_by_id: reviewer.id)
             .update_all(build_review_claimed_by_id: nil, build_review_claimed_at: nil)
    end
  end

  def self.release_all_for_reviewer!(reviewer:, type:)
    type = type.to_sym
    raise ArgumentError, "type must be :design or :build" unless %i[design build].include?(type)

    cutoff = TTL.ago

    if type == :design
      Project.where(design_review_claimed_by_id: reviewer.id)
             .where("design_review_claimed_at >= ?", cutoff)
             .update_all(design_review_claimed_by_id: nil, design_review_claimed_at: nil)
    else
      Project.where(build_review_claimed_by_id: reviewer.id)
             .where("build_review_claimed_at >= ?", cutoff)
             .update_all(build_review_claimed_by_id: nil, build_review_claimed_at: nil)
    end
  end

  def self.claimed_by_other?(project:, reviewer:, type:)
    type = type.to_sym
    raise ArgumentError, "type must be :design or :build" unless %i[design build].include?(type)

    cutoff = TTL.ago

    if type == :design
      project.design_review_claimed_by_id.present? &&
        project.design_review_claimed_by_id != reviewer.id &&
        project.design_review_claimed_at.present? &&
        project.design_review_claimed_at >= cutoff
    else
      project.build_review_claimed_by_id.present? &&
        project.build_review_claimed_by_id != reviewer.id &&
        project.build_review_claimed_at.present? &&
        project.build_review_claimed_at >= cutoff
    end
  end

  def self.claimed_by?(project:, reviewer:, type:)
    type = type.to_sym
    raise ArgumentError, "type must be :design or :build" unless %i[design build].include?(type)

    cutoff = TTL.ago

    if type == :design
      project.design_review_claimed_by_id == reviewer.id &&
        project.design_review_claimed_at.present? &&
        project.design_review_claimed_at >= cutoff
    else
      project.build_review_claimed_by_id == reviewer.id &&
        project.build_review_claimed_at.present? &&
        project.build_review_claimed_at >= cutoff
    end
  end

  def self.has_any_claim?(reviewer:, type:)
    type = type.to_sym
    raise ArgumentError, "type must be :design or :build" unless %i[design build].include?(type)

    cutoff = TTL.ago

    if type == :design
      Project.where(design_review_claimed_by_id: reviewer.id)
             .where("design_review_claimed_at >= ?", cutoff)
             .exists?
    else
      Project.where(build_review_claimed_by_id: reviewer.id)
             .where("build_review_claimed_at >= ?", cutoff)
             .exists?
    end
  end
end
