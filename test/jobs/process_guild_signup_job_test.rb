require "test_helper"

class ProcessGuildSignupJobTest < ActiveJob::TestCase
  # we don't want the global `fixtures :all` in test_helper since some of
  # the yml files (e.g. airtable_syncs) are out-of-date and raise errors when
  # loaded.  telling Rails to load an empty list of fixtures prevents it from
  # touching any of them.
  fixtures []

  setup do
    @guild = Guild.create!(city: "TestCity", name: "Test Guild")
  end

  test "third organizer is demoted to attendee and persisted" do
    # create two existing organizers
    org1 = User.create!(email: "org1@example.com", is_banned: false)
    org2 = User.create!(email: "org2@example.com", is_banned: false)
    [org1, org2].each do |u|
      u.stub :has_approved_project?, true do
        GuildSignup.create!(user: u, guild: @guild, name: "Foo", email: "foo@example.com", role: :organizer)
      end
    end

    third = User.create!(email: "third@example.com", is_banned: false)
    third.stub :has_approved_project?, true do
      signup = GuildSignup.create!(user: third, guild: @guild, name: "Third", email: "third@example.com", role: :organizer)

      # stub Slack client so we don't hit real API
      Slack::Web::Client.stub :new, Object.new do
        ProcessGuildSignupJob.perform_now(signup.id)
      end

      signup.reload
      assert signup.attendee?, "signup should have been converted to attendee"
    end
  end

  test "topic is always refreshed when job runs" do
    @guild.update!(slack_channel_id: "C123")
    called = false
    def @guild.update_slack_topic
      super
      @topic_updated = true
    end

    user = User.create!(email: "u@example.com", is_banned: false)
    user.stub :has_approved_project?, true do
      signup = GuildSignup.create!(user: user, guild: @guild, name: "Name", email: "e@example.com", role: :organizer)
      Slack::Web::Client.stub :new, Object.new do
        ProcessGuildSignupJob.perform_now(signup.id)
      end
    end

    assert @guild.instance_variable_get(:@topic_updated), "Slack topic should have been updated"
  end

  test "job is enqueued after commit" do
    assert_enqueued_with(job: ProcessGuildSignupJob) do
      user = User.create!(email: "enqueue@example.com", is_banned: false)
      user.stub :has_approved_project?, true do
        GuildSignup.create!(user: user, guild: @guild, name: "N", email: "e@example.com", role: :attendee)
      end
    end
  end
end
