# Kill-switch for the end of the Blueprint program.
#
# When the `blueprint_ended` Flipper flag is on, the program is frozen: no new
# journal entries, no new file uploads, no new accounts. Everything already
# submitted stays readable.
#
# Named ProgramStatus rather than Blueprint because `Blueprint` is already the
# Rails application module (see config/application.rb).
module ProgramStatus
  MESSAGE = "Blueprint has ended"

  # Raised when someone tries to sign up after the program has ended. Both
  # AuthController#create and #create_hca already rescue StandardError and
  # surface e.message, so this reaches the user as MESSAGE.
  class AccountCreationClosed < StandardError
    def initialize(message = MESSAGE)
      super
    end
  end

  def self.ended?
    Flipper.enabled?(:blueprint_ended)
  end

  # Admins keep write access so they can still run the shop, fix content, and
  # process imports after the program closes.
  def self.ended_for?(user)
    ended? && !user&.admin?
  end
end
