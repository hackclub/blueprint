class GuildInvitesController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :set_guild_from_token

  def show
    @signup = current_user&.guild_signups&.find_by(guild: @guild)
  end

  def accept
    unless current_user
      session[:after_login_redirect] = guild_invite_path(token: params[:token])
      redirect_to login_path, alert: "Sign up or log in to join this guild!"
      return
    end

    if current_user.guild_signups.exists?(guild: @guild)
      redirect_to guild_invite_path(token: params[:token]), alert: "You're already signed up for this guild!"
      return
    end

    @signup = current_user.guild_signups.build(
      guild: @guild,
      role: :attendee,
      name: current_user.display_name,
      email: current_user.email,
      country: @guild.country,
      skip_slack_validation: true
    )

    if @signup.save
      notice = if current_user.slack_id.present?
        "You've joined the #{@guild.name}! Check Slack for your guild channel."
      else
        "You've joined the #{@guild.name}! Connect your Slack account on the home page to get added to the guild channel."
      end
      redirect_to guilds_path, notice: notice
    else
      redirect_to guild_invite_path(token: params[:token]),
        alert: @signup.errors.full_messages.join(", ")
    end
  end

  private

  def set_guild_from_token
    payload = self.class.verify_token(params[:token])
    if payload.nil?
      redirect_to guilds_path, alert: "This invite link is invalid or has expired."
      return
    end

    @guild = Guild.find_by(id: payload[:guild_id])
    unless @guild
      redirect_to guilds_path, alert: "This guild no longer exists."
      return
    end

    if @guild.closed?
      redirect_to guilds_path, alert: "This guild is closed."
    end
  end

  def self.generate_token(guild_id)
    verifier.generate({ guild_id: guild_id }, purpose: :guild_invite)
  end

  def self.verify_token(token)
    data = verifier.verify(token, purpose: :guild_invite)
    data = data.symbolize_keys if data.respond_to?(:symbolize_keys)
    data
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def self.verifier
    Rails.application.message_verifier("guild_invite")
  end
end
