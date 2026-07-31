# Server-side backstop for the upload block.
#
# config/initializers/block_uploads_when_program_ended.rb closes the direct-upload
# endpoint that every form in the app actually uses. This catches the other route:
# a plain multipart POST that attaches a file straight through model assignment,
# which never touches that endpoint.
#
# Only *new* attachments are rejected. Detaching or purging an existing one still
# works, so users can clean up their own files after the program closes.
module UploadsCloseWithProgram
  extend ActiveSupport::Concern

  CREATE_CHANGES = [
    ActiveStorage::Attached::Changes::CreateOne,
    ActiveStorage::Attached::Changes::CreateMany
  ].freeze

  included do
    validate :reject_new_uploads_after_program_end
  end

  private

  # Exemption is based on the record owner, since a model cannot see the request.
  # The endpoint guard is what keys off the actual acting user.
  def reject_new_uploads_after_program_end
    return if attachment_changes.empty?
    return unless ProgramStatus.ended_for?(try(:user))

    attachment_changes.each do |name, change|
      next unless CREATE_CHANGES.any? { |klass| change.is_a?(klass) }

      errors.add(name.to_sym, ProgramStatus::MESSAGE)
    end
  end
end
