# == Route Map
#
#                                   Prefix Verb URI Pattern                                                                                       Controller#Action
#                                               /assets                                                                                           Propshaft::Server
#                       rails_health_check GET  /up(.:format)                                                                                     rails/health#show
#                                     root GET  /                                                                                                 landing#index
#         turbo_recede_historical_location GET  /recede_historical_location(.:format)                                                             turbo/native/navigation#recede
#         turbo_resume_historical_location GET  /resume_historical_location(.:format)                                                             turbo/native/navigation#resume
#        turbo_refresh_historical_location GET  /refresh_historical_location(.:format)                                                            turbo/native/navigation#refresh
#            rails_postmark_inbound_emails POST /rails/action_mailbox/postmark/inbound_emails(.:format)                                           action_mailbox/ingresses/postmark/inbound_emails#create
#               rails_relay_inbound_emails POST /rails/action_mailbox/relay/inbound_emails(.:format)                                              action_mailbox/ingresses/relay/inbound_emails#create
#            rails_sendgrid_inbound_emails POST /rails/action_mailbox/sendgrid/inbound_emails(.:format)                                           action_mailbox/ingresses/sendgrid/inbound_emails#create
#      rails_mandrill_inbound_health_check GET  /rails/action_mailbox/mandrill/inbound_emails(.:format)                                           action_mailbox/ingresses/mandrill/inbound_emails#health_check
#            rails_mandrill_inbound_emails POST /rails/action_mailbox/mandrill/inbound_emails(.:format)                                           action_mailbox/ingresses/mandrill/inbound_emails#create
#             rails_mailgun_inbound_emails POST /rails/action_mailbox/mailgun/inbound_emails/mime(.:format)                                       action_mailbox/ingresses/mailgun/inbound_emails#create
#           rails_conductor_inbound_emails GET  /rails/conductor/action_mailbox/inbound_emails(.:format)                                          rails/conductor/action_mailbox/inbound_emails#index
#                                          POST /rails/conductor/action_mailbox/inbound_emails(.:format)                                          rails/conductor/action_mailbox/inbound_emails#create
#        new_rails_conductor_inbound_email GET  /rails/conductor/action_mailbox/inbound_emails/new(.:format)                                      rails/conductor/action_mailbox/inbound_emails#new
#            rails_conductor_inbound_email GET  /rails/conductor/action_mailbox/inbound_emails/:id(.:format)                                      rails/conductor/action_mailbox/inbound_emails#show
# new_rails_conductor_inbound_email_source GET  /rails/conductor/action_mailbox/inbound_emails/sources/new(.:format)                              rails/conductor/action_mailbox/inbound_emails/sources#new
#    rails_conductor_inbound_email_sources POST /rails/conductor/action_mailbox/inbound_emails/sources(.:format)                                  rails/conductor/action_mailbox/inbound_emails/sources#create
#    rails_conductor_inbound_email_reroute POST /rails/conductor/action_mailbox/:inbound_email_id/reroute(.:format)                               rails/conductor/action_mailbox/reroutes#create
# rails_conductor_inbound_email_incinerate POST /rails/conductor/action_mailbox/:inbound_email_id/incinerate(.:format)                            rails/conductor/action_mailbox/incinerates#create
#                       rails_service_blob GET  /rails/active_storage/blobs/redirect/:signed_id/*filename(.:format)                               active_storage/blobs/redirect#show
#                 rails_service_blob_proxy GET  /rails/active_storage/blobs/proxy/:signed_id/*filename(.:format)                                  active_storage/blobs/proxy#show
#                                          GET  /rails/active_storage/blobs/:signed_id/*filename(.:format)                                        active_storage/blobs/redirect#show
#                rails_blob_representation GET  /rails/active_storage/representations/redirect/:signed_blob_id/:variation_key/*filename(.:format) active_storage/representations/redirect#show
#          rails_blob_representation_proxy GET  /rails/active_storage/representations/proxy/:signed_blob_id/:variation_key/*filename(.:format)    active_storage/representations/proxy#show
#                                          GET  /rails/active_storage/representations/:signed_blob_id/:variation_key/*filename(.:format)          active_storage/representations/redirect#show
#                       rails_disk_service GET  /rails/active_storage/disk/:encoded_key/*filename(.:format)                                       active_storage/disk#show
#                update_rails_disk_service PUT  /rails/active_storage/disk/:encoded_token(.:format)                                               active_storage/disk#update
#                     rails_direct_uploads POST /rails/active_storage/direct_uploads(.:format)                                                    active_storage/direct_uploads#create
class AdminConstraint
  def self.matches?(request)
    return false unless request.session[:user_id]

    user = User.find_by(id: request.session[:user_id])
    user&.admin?
  end
end

class ReviewerConstraint
  def self.matches?(request)
    return false unless request.session[:user_id]

    user = User.find_by(id: request.session[:user_id])
    user&.reviewer_perms?
  end
end

Rails.application.routes.draw do
  resources :shop_items, only: [ :new, :create ]
  resources :shop_orders, only: [ :index, :new, :create ]
  get "buy/:item_id", to: "shop_orders#new", as: :buy_item
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route for unauthenticated users
  root "landing#index"
  get "landing" => "landing#authed", as: :landing

  get "sorry" => "sorry#index", as: :sorry

  # Referral system
  get "r/:id" => "referral#show", as: :referral

  # Authentication
  get "auth/login" => "auth#index", as: :login
  get "auth/slack" => "auth#new", as: :slack_login
  get "auth/github" => "auth#github", as: :github_login
  get "auth/slack/callback" => "auth#create", as: :slack_callback
  get "auth/github/callback" => "auth#create_github", as: :github_callback
  post "auth/email" => "auth#create_email", as: :login_email
  delete "auth/logout" => "auth#destroy", as: :logout
  post "auth/track" => "auth#track", as: :auth_tracks
  get "auth/idv" => "auth#idv", as: :idv
  get "idv_callback" => "auth#idv_callback", as: :idv_callback

  get "/utm_source" => "landing#utm_source", as: :utm_source
  get "/utm_source=feedback-email" => "landing#utm_source", as: :utm_source_feedback_email

  get "home" => "home#index", as: :home

  get "api/site" => "api#site", as: :api_site
  post "api/stickers" => "api#stickers", as: :api_stickers
  post "api/report_grant_given" => "api#report_grant_given", as: :api_report_grant_given
  post "api/report_free_stickers_claimed" => "api#report_free_stickers_claimed", as: :api_report_free_stickers_claimed

  resources :projects, only: [ :index, :new, :create, :show, :edit, :update, :destroy ] do
    member do
      get :ship
      post :follow
      post :unfollow
    end
    resources :journal_entries, only: [ :create, :destroy, :show, :edit, :update ]
    resources :kudos, only: [ :create, :destroy ]

    post :check_github_repo, on: :collection
    post :check_bom, on: :collection
    post :check_readme, on: :collection
  end
  get "explore" => "projects#explore", as: :explore
  get "leaderboard" => "leaderboards#index", as: :leaderboard

  get "toolbag" => "toolbag#index", as: :toolbag

  get "users/me", to: "users#me", as: :me
  resources :users, only: [ :show ] do
    post :invite_to_slack, on: :collection
    post :mcg_check, on: :collection
    post :update_timezone, on: :collection
  end

  # Docs -> docs/docs (formerly guides)
  get "docs", to: "guides#docs", as: :docs
  get "docs/*slug", to: "guides#docs"

  # Guides -> docs/guides (formerly starter-projects)
  get "guides", to: "guides#guides", as: :guides
  get "guides/*slug", to: "guides#guides",
      constraints: { slug: /[a-z0-9\/_\-]+/ }
  get "faq", to: "guides#faq", as: :faq

  namespace :admin do
    post "stop_impersonating", to: "users#stop_impersonating"

    constraints AdminConstraint do
      mount MissionControl::Jobs::Engine, at: "jobs"
      mount Flipper::UI.app(Flipper), at: "flipper"
      mount Blazer::Engine, at: "blazer"

      resources :projects, only: [ :index, :show ] do
        post :delete, on: :member
        post :revive, on: :member
      end
      resources :allowed_emails, only: [ :index, :create, :destroy ]

      resources :users, only: [ :index, :show ] do
        post :grant_reviewer, on: :member
        post :revoke_to_user, on: :member
        patch :update_internal_notes, on: :member
        post :impersonate, on: :member
      end

      resources :hcb_transactions, only: [ :index ]
    end

    constraints ReviewerConstraint do
      get "/" => "static_pages#index", as: :root

      get "design_reviews", to: "design_reviews#index", as: :design_reviews
      get "design_reviews/random", to: "design_reviews#show_random", as: :random_design_review
      get "design_reviews/:id", to: "design_reviews#show", as: :design_review
      post "design_reviews/:id", to: "design_reviews#create", as: :design_review_create

      get "build_reviews", to: "build_reviews#index", as: :build_reviews
      get "build_reviews/random", to: "build_reviews#show_random", as: :random_build_review
      get "build_reviews/:id", to: "build_reviews#show", as: :build_review
      post "build_reviews/:id", to: "build_reviews#create", as: :build_review_create

      resources :projects, only: [ :index, :show ]
      resources :users, only: [ :index, :show, :update ]
    end
  end
end
