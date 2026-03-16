class AddCountryAndAttendeeActivitiesToGuildSignups < ActiveRecord::Migration[8.0]
  def change
    add_column :guild_signups, :country, :string
    add_column :guild_signups, :attendee_activities, :text
  end
end
