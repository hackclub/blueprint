# == Route Map
#
# Routes for application:
#                                   Prefix Verb   URI Pattern                                                                                   Controller#Action
#                           slack_commands POST   /slack/commands(.:format)                                                                     slack_commands#handle
#                            guild_signups POST   /guild_signups(.:format)                                                                      guild_signups#create
#                         new_guild_signup GET    /guild_signups/new(.:format)                                                                  guild_signups#new
#                     guild_signups_signup POST   /guild_signups/signup(.:format)                                                               guild_signups#signup
#                     guild_signups_verify POST   /guild_signups/verify(.:format)                                                               guild_signups#verify
#                    guild_signups_success GET    /guild_signups/success(.:format)                                                              guild_signups#success
#                               shop_items POST   /shop_items(.:format)                                                                         shop_items#create
#                            new_shop_item GET    /shop_items/new(.:format)                                                                     shop_items#new
#                              shop_orders GET    /shop_orders(.:format)                                                                        shop_orders#index
#                                          POST   /shop_orders(.:format)                                                                        shop_orders#create
#                           new_shop_order GET    /shop_orders/new(.:format)                                                                    shop_orders#new
#                                 buy_item GET    /buy/:item_id(.:format)                                                                       shop_orders#new
#                       rails_health_check GET    /up(.:format)                                                                                 rails/health#show
#                                     root GET    /                                                                                             landing#index
#                                  landing GET    /landing(.:format)                                                                            landing#authed
#                                countdown GET    /countdown(.:format)                                                                          countdown#index
#                                    sorry GET    /sorry(.:format)                                                                              sorry#index
#                                    adult GET    /adult(.:format)                                                                              adult#index
#                                 referral GET    /r/:id(.:format)                                                                              referral#show
#                          guilds_map_data GET    /guilds/map_data(.:format)                                                                    guilds#map_data
#                          guild_dashboard GET    /guilds/dashboard(.:format)                                                                   guilds#dashboard
#                guild_create_announcement POST   /guilds/dashboard/announce(.:format)                                                          guilds#create_announcement
#                guild_delete_announcement DELETE /guilds/dashboard/announce(.:format)                                                          guilds#delete_announcement
#                              guild_leave DELETE /guilds/dashboard/leave(.:format)                                                             guilds#leave_guild
#                      guild_close_signups POST   /guilds/dashboard/close_signups(.:format)                                                     guilds#close_signups
#                     guild_reopen_signups POST   /guilds/dashboard/reopen_signups(.:format)                                                    guilds#reopen_signups
#                     guild_dismiss_notice POST   /guilds/dashboard/dismiss_notice/:key(.:format)                                               guilds#dismiss_notice
#                                    login GET    /auth/login(.:format)                                                                         auth#index
#                              slack_login GET    /auth/slack(.:format)                                                                         auth#new
#                             github_login GET    /auth/github(.:format)                                                                        auth#github
#                                hca_login GET    /auth/hca(.:format)                                                                           auth#new_hca
#                           slack_callback GET    /auth/slack/callback(.:format)                                                                auth#create
#                          github_callback GET    /auth/github/callback(.:format)                                                               auth#create_github
#                             hca_callback GET    /auth/hca/callback(.:format)                                                                  auth#create_hca
#                              login_email POST   /auth/email(.:format)                                                                         auth#create_email
#                                   logout DELETE /auth/logout(.:format)                                                                        auth#destroy
#                              auth_tracks POST   /auth/track(.:format)                                                                         auth#track
#                                      idv GET    /auth/idv(.:format)                                                                           auth#idv
#                                idv_start GET    /auth/idv/start(.:format)                                                                     auth#idv_start
#                             idv_callback GET    /idv_callback(.:format)                                                                       auth#idv_callback
#                         age_verification GET    /auth/age(.:format)                                                                           auth#age
#                                 auth_age POST   /auth/age(.:format)                                                                           auth#submit_age
#                                hcb_oauth GET    /auth/hcb(.:format)                                                                           hcb_oauth#start
#                             hcb_callback GET    /auth/hcb/callback(.:format)                                                                  hcb_oauth#callback
#                           hcb_disconnect DELETE /auth/hcb(.:format)                                                                           hcb_oauth#disconnect
#                               utm_source GET    /utm_source(.:format)                                                                         landing#utm_source
#                utm_source_feedback_email GET    /utm_source=feedback-email(.:format)                                                          landing#utm_source
#                                      amd GET    /amd(.:format)                                                                                amd#index
#                                     home GET    /home(.:format)                                                                               home#index
#                                 api_site GET    /api/site(.:format)                                                                           api#site
#                             api_stickers POST   /api/stickers(.:format)                                                                       api#stickers
#                   api_report_grant_given POST   /api/report_grant_given(.:format)                                                             api#report_grant_given
#         api_report_free_stickers_claimed POST   /api/report_free_stickers_claimed(.:format)                                                   api#report_free_stickers_claimed
#                  api_unfinished_projects GET    /api/unfinished_projects(.:format)                                                            api#unfinished_projects
#                       api_privacy_delete POST   /api/privacy/delete(.:format)                                                                 privacy#delete
#                       api_privacy_export POST   /api/privacy/export(.:format)                                                                 privacy#export
#                             ship_project GET    /projects/:id/ship(.:format)                                                                  projects#ship
#                           follow_project POST   /projects/:id/follow(.:format)                                                                projects#follow
#                         unfollow_project POST   /projects/:id/unfollow(.:format)                                                              projects#unfollow
#           export_project_journal_entries GET    /projects/:project_id/journal_entries/export(.:format)                                        journal_entries#export
#                  project_journal_entries POST   /projects/:project_id/journal_entries(.:format)                                               journal_entries#create
#               edit_project_journal_entry GET    /projects/:project_id/journal_entries/:id/edit(.:format)                                      journal_entries#edit
#                    project_journal_entry GET    /projects/:project_id/journal_entries/:id(.:format)                                           journal_entries#show
#                                          PATCH  /projects/:project_id/journal_entries/:id(.:format)                                           journal_entries#update
#                                          PUT    /projects/:project_id/journal_entries/:id(.:format)                                           journal_entries#update
#                                          DELETE /projects/:project_id/journal_entries/:id(.:format)                                           journal_entries#destroy
#                            project_kudos POST   /projects/:project_id/kudos(.:format)                                                         kudos#create
#                             project_kudo DELETE /projects/:project_id/kudos/:id(.:format)                                                     kudos#destroy
#               check_github_repo_projects POST   /projects/check_github_repo(.:format)                                                         projects#check_github_repo
#                       check_bom_projects POST   /projects/check_bom(.:format)                                                                 projects#check_bom
#                    check_readme_projects POST   /projects/check_readme(.:format)                                                              projects#check_readme
#                      list_repos_projects GET    /projects/list_repos(.:format)                                                                projects#list_repos
#                                 projects GET    /projects(.:format)                                                                           projects#index
#                                          POST   /projects(.:format)                                                                           projects#create
#                              new_project GET    /projects/new(.:format)                                                                       projects#new
#                             edit_project GET    /projects/:id/edit(.:format)                                                                  projects#edit
#                                  project GET    /projects/:id(.:format)                                                                       projects#show
#                                          PATCH  /projects/:id(.:format)                                                                       projects#update
#                                          PUT    /projects/:id(.:format)                                                                       projects#update
#                                          DELETE /projects/:id(.:format)                                                                       projects#destroy
#                                  explore GET    /explore(.:format)                                                                            projects#explore
#                                    stats GET    /stats(.:format)                                                                              stats#index
#                              leaderboard GET    /leaderboard(.:format)                                                                        leaderboards#index
#                                   guilds GET    /guilds(.:format)                                                                             guilds#index
#                             guild_invite GET    /guilds/invite/:slug(.:format)                                                                guild_invites#show
#                      guild_invite_signup POST   /guilds/invite/:slug/signup(.:format)                                                         guild_invites#signup
#                      guild_invite_verify POST   /guilds/invite/:slug/verify(.:format)                                                         guild_invites#verify
#                      accept_guild_invite POST   /guilds/invite/:slug/accept(.:format)                                                         guild_invites#accept
#                     guild_invite_success GET    /guilds/invite/:slug/success(.:format)                                                        guild_invites#success
#                                  toolbag GET    /toolbag(.:format)                                                                            toolbag#index
#                                       me GET    /users/me(.:format)                                                                           users#me
#                    invite_to_slack_users POST   /users/invite_to_slack(.:format)                                                              users#invite_to_slack
#                          mcg_check_users POST   /users/mcg_check(.:format)                                                                    users#mcg_check
#                    update_timezone_users POST   /users/update_timezone(.:format)                                                              users#update_timezone
#                         toggle_pro_users POST   /users/toggle_pro(.:format)                                                                   users#toggle_pro
#                                     user GET    /users/:id(.:format)                                                                          users#show
#                                     team GET    /team(.:format)                                                                               team#index
#                                    about GET    /about(.:format)                                                                              markdown#about
#                                          GET    /about/*slug(.:format)                                                                        markdown#about
#                                     docs GET    /docs(.:format)                                                                               markdown#docs
#                                          GET    /docs/*slug(.:format)                                                                         markdown#docs
#                                resources GET    /resources(.:format)                                                                          markdown#resources
#                                          GET    /resources/*slug(.:format)                                                                    markdown#resources {slug: /[a-z0-9\/_\-]+/}
#                                   guides GET    /guides(.:format)                                                                             markdown#guides
#                                          GET    /guides/*slug(.:format)                                                                       markdown#guides
#                         starter_projects GET    /starter-projects(.:format)                                                                   markdown#starter_projects
#                                          GET    /starter-projects/*slug(.:format)                                                             markdown#starter_projects
#                                  hackpad GET    /hackpad(.:format)                                                                            markdown#hackpad
#                                          GET    /hackpad/*slug(.:format)                                                                      markdown#hackpad
#                                      faq GET    /faq(.:format)                                                                                markdown#faq
#                                prototype GET    /prototype(.:format)                                                                          prototype#index
#                                   poster GET    /posters/:id(.:format)                                                                        posters#show
#                  customs_receipt_package GET    /packages/:id/customs_receipt(.:format)                                                       packages#customs_receipt
#                 admin_stop_impersonating POST   /admin/stop_impersonating(.:format)                                                           admin/users#stop_impersonating
#               admin_mission_control_jobs        /admin/jobs                                                                                   MissionControl::Jobs::Engine
#                                                 /admin/flipper                                                                                Flipper::UI
#                             admin_blazer        /admin/blazer                                                                                 Blazer::Engine
#     admin_invalidate_privileged_sessions POST   /admin/invalidate_privileged_sessions(.:format)                                               admin/static_pages#invalidate_privileged_sessions
#         preview_admin_pirate_ship_import POST   /admin/pirate_ship_import/preview(.:format)                                                   admin/pirate_ship_imports#preview
#             new_admin_pirate_ship_import GET    /admin/pirate_ship_import/new(.:format)                                                       admin/pirate_ship_imports#new
#                 admin_pirate_ship_import POST   /admin/pirate_ship_import(.:format)                                                           admin/pirate_ship_imports#create
#                     delete_admin_project POST   /admin/projects/:id/delete(.:format)                                                          admin/projects#delete
#                     revive_admin_project POST   /admin/projects/:id/revive(.:format)                                                          admin/projects#revive
#                 mark_viral_admin_project POST   /admin/projects/:id/mark_viral(.:format)                                                      admin/projects#mark_viral
#               unmark_viral_admin_project POST   /admin/projects/:id/unmark_viral(.:format)                                                    admin/projects#unmark_viral
#            toggle_unlisted_admin_project POST   /admin/projects/:id/toggle_unlisted(.:format)                                                 admin/projects#toggle_unlisted
#        switch_review_phase_admin_project POST   /admin/projects/:id/switch_review_phase(.:format)                                             admin/projects#switch_review_phase
#    force_fix_review_status_admin_project POST   /admin/projects/:id/force_fix_review_status(.:format)                                         admin/projects#force_fix_review_status
#                           admin_projects GET    /admin/projects(.:format)                                                                     admin/projects#index
#                            admin_project GET    /admin/projects/:id(.:format)                                                                 admin/projects#show
#                     admin_allowed_emails GET    /admin/allowed_emails(.:format)                                                               admin/allowed_emails#index
#                                          POST   /admin/allowed_emails(.:format)                                                               admin/allowed_emails#create
#                      admin_allowed_email DELETE /admin/allowed_emails/:id(.:format)                                                           admin/allowed_emails#destroy
#                   grant_admin_admin_user POST   /admin/users/:id/grant_admin(.:format)                                                        admin/users#grant_admin
#                  revoke_admin_admin_user POST   /admin/users/:id/revoke_admin(.:format)                                                       admin/users#revoke_admin
#                grant_reviewer_admin_user POST   /admin/users/:id/grant_reviewer(.:format)                                                     admin/users#grant_reviewer
#               revoke_reviewer_admin_user POST   /admin/users/:id/revoke_reviewer(.:format)                                                    admin/users#revoke_reviewer
#               grant_fulfiller_admin_user POST   /admin/users/:id/grant_fulfiller(.:format)                                                    admin/users#grant_fulfiller
#              revoke_fulfiller_admin_user POST   /admin/users/:id/revoke_fulfiller(.:format)                                                   admin/users#revoke_fulfiller
#              grant_shopkeeper_admin_user POST   /admin/users/:id/grant_shopkeeper(.:format)                                                   admin/users#grant_shopkeeper
#             revoke_shopkeeper_admin_user POST   /admin/users/:id/revoke_shopkeeper(.:format)                                                  admin/users#revoke_shopkeeper
#                revoke_to_user_admin_user POST   /admin/users/:id/revoke_to_user(.:format)                                                     admin/users#revoke_to_user
#       grant_submission_bypass_admin_user POST   /admin/users/:id/grant_submission_bypass(.:format)                                            admin/users#grant_submission_bypass
#      revoke_submission_bypass_admin_user POST   /admin/users/:id/revoke_submission_bypass(.:format)                                           admin/users#revoke_submission_bypass
#                   impersonate_admin_user POST   /admin/users/:id/impersonate(.:format)                                                        admin/users#impersonate
#                           ban_admin_user POST   /admin/users/:id/ban(.:format)                                                                admin/users#ban
#                         unban_admin_user POST   /admin/users/:id/unban(.:format)                                                              admin/users#unban
#         add_ticket_adjustment_admin_user POST   /admin/users/:id/add_ticket_adjustment(.:format)                                              admin/users#add_ticket_adjustment
#                              admin_users GET    /admin/users(.:format)                                                                        admin/users#index
#                               admin_user GET    /admin/users/:id(.:format)                                                                    admin/users#show
#                   admin_hcb_transactions GET    /admin/hcb_transactions(.:format)                                                             admin/hcb_transactions#index
#                          admin_shop_item DELETE /admin/shop_items/:id(.:format)                                                               admin/shop_items#destroy
#                               admin_root GET    /admin(.:format)                                                                              admin/static_pages#index
#                             admin_guilds GET    /admin/guilds(.:format)                                                                       admin/guilds#index
#                              admin_guild GET    /admin/guilds/:id(.:format)                                                                   admin/guilds#show
#                     admin_design_reviews GET    /admin/design_reviews(.:format)                                                               admin/design_reviews#index
#                 admin_next_design_review GET    /admin/design_reviews/next(/:ysws_type)(.:format)                                             admin/design_reviews#show_next
#                      admin_design_review GET    /admin/design_reviews/:id(.:format)                                                           admin/design_reviews#show
#               admin_design_review_create POST   /admin/design_reviews/:id(.:format)                                                           admin/design_reviews#create
#                      admin_build_reviews GET    /admin/build_reviews(.:format)                                                                admin/build_reviews#index
#                  admin_next_build_review GET    /admin/build_reviews/next(/:ysws_type)(.:format)                                              admin/build_reviews#show_next
#                       admin_build_review GET    /admin/build_reviews/:id(.:format)                                                            admin/build_reviews#show
#                admin_build_review_create POST   /admin/build_reviews/:id(.:format)                                                            admin/build_reviews#create
#    admin_promote_first_pass_build_review POST   /admin/build_reviews/:id/promote_first_pass(.:format)                                         admin/build_reviews#promote_first_pass
#       admin_deny_first_pass_build_review POST   /admin/build_reviews/:id/deny_first_pass(.:format)                                            admin/build_reviews#deny_first_pass
#                         admin_ai_reviews GET    /admin/ai_reviews(.:format)                                                                   admin/ai_reviews#index
#                          admin_ai_review GET    /admin/ai_reviews/:id(.:format)                                                               admin/ai_reviews#show
#                   admin_ai_review_create POST   /admin/ai_reviews/:project_id(.:format)                                                       admin/ai_reviews#create
#                                          GET    /admin/projects(.:format)                                                                     admin/projects#index
#                                          GET    /admin/projects/:id(.:format)                                                                 admin/projects#show
#         update_internal_notes_admin_user PATCH  /admin/users/:id/update_internal_notes(.:format)                                              admin/users#update_internal_notes
#                                          GET    /admin/users(.:format)                                                                        admin/users#index
#                                          GET    /admin/users/:id(.:format)                                                                    admin/users#show
#                                          PATCH  /admin/users/:id(.:format)                                                                    admin/users#update
#                                          PUT    /admin/users/:id(.:format)                                                                    admin/users#update
#                 approve_admin_shop_order POST   /admin/shop_orders/:id/approve(.:format)                                                      admin/shop_orders#approve
#                  reject_admin_shop_order POST   /admin/shop_orders/:id/reject(.:format)                                                       admin/shop_orders#reject
#                    hold_admin_shop_order POST   /admin/shop_orders/:id/hold(.:format)                                                         admin/shop_orders#hold
#                 fulfill_admin_shop_order POST   /admin/shop_orders/:id/fulfill(.:format)                                                      admin/shop_orders#fulfill
#            update_notes_admin_shop_order PATCH  /admin/shop_orders/:id/update_notes(.:format)                                                 admin/shop_orders#update_notes
#                        admin_shop_orders GET    /admin/shop_orders(.:format)                                                                  admin/shop_orders#index
#                         admin_shop_order GET    /admin/shop_orders/:id(.:format)                                                              admin/shop_orders#show
#                         admin_shop_items POST   /admin/shop_items(.:format)                                                                   admin/shop_items#create
#                      new_admin_shop_item GET    /admin/shop_items/new(.:format)                                                               admin/shop_items#new
#                     edit_admin_shop_item GET    /admin/shop_items/:id/edit(.:format)                                                          admin/shop_items#edit
#                                          PATCH  /admin/shop_items/:id(.:format)                                                               admin/shop_items#update
#                                          PUT    /admin/shop_items/:id(.:format)                                                               admin/shop_items#update
#                                          GET    /admin/shop_items(.:format)                                                                   admin/shop_items#index
#                                          GET    /admin/shop_items/:id(.:format)                                                               admin/shop_items#show
#         turbo_recede_historical_location GET    /recede_historical_location(.:format)                                                         turbo/native/navigation#recede
#         turbo_resume_historical_location GET    /resume_historical_location(.:format)                                                         turbo/native/navigation#resume
#        turbo_refresh_historical_location GET    /refresh_historical_location(.:format)                                                        turbo/native/navigation#refresh
#            rails_postmark_inbound_emails POST   /rails/action_mailbox/postmark/inbound_emails(.:format)                                       action_mailbox/ingresses/postmark/inbound_emails#create
#               rails_relay_inbound_emails POST   /rails/action_mailbox/relay/inbound_emails(.:format)                                          action_mailbox/ingresses/relay/inbound_emails#create
#            rails_sendgrid_inbound_emails POST   /rails/action_mailbox/sendgrid/inbound_emails(.:format)                                       action_mailbox/ingresses/sendgrid/inbound_emails#create
#      rails_mandrill_inbound_health_check GET    /rails/action_mailbox/mandrill/inbound_emails(.:format)                                       action_mailbox/ingresses/mandrill/inbound_emails#health_check
#            rails_mandrill_inbound_emails POST   /rails/action_mailbox/mandrill/inbound_emails(.:format)                                       action_mailbox/ingresses/mandrill/inbound_emails#create
#             rails_mailgun_inbound_emails POST   /rails/action_mailbox/mailgun/inbound_emails/mime(.:format)                                   action_mailbox/ingresses/mailgun/inbound_emails#create
#           rails_conductor_inbound_emails GET    /rails/conductor/action_mailbox/inbound_emails(.:format)                                      rails/conductor/action_mailbox/inbound_emails#index
#                                          POST   /rails/conductor/action_mailbox/inbound_emails(.:format)                                      rails/conductor/action_mailbox/inbound_emails#create
#        new_rails_conductor_inbound_email GET    /rails/conductor/action_mailbox/inbound_emails/new(.:format)                                  rails/conductor/action_mailbox/inbound_emails#new
#            rails_conductor_inbound_email GET    /rails/conductor/action_mailbox/inbound_emails/:id(.:format)                                  rails/conductor/action_mailbox/inbound_emails#show
# new_rails_conductor_inbound_email_source GET    /rails/conductor/action_mailbox/inbound_emails/sources/new(.:format)                          rails/conductor/action_mailbox/inbound_emails/sources#new
#    rails_conductor_inbound_email_sources POST   /rails/conductor/action_mailbox/inbound_emails/sources(.:format)                              rails/conductor/action_mailbox/inbound_emails/sources#create
#    rails_conductor_inbound_email_reroute POST   /rails/conductor/action_mailbox/:inbound_email_id/reroute(.:format)                           rails/conductor/action_mailbox/reroutes#create
# rails_conductor_inbound_email_incinerate POST   /rails/conductor/action_mailbox/:inbound_email_id/incinerate(.:format)                        rails/conductor/action_mailbox/incinerates#create
#                       rails_service_blob GET    /user-attachments/blobs/redirect/:signed_id/*filename(.:format)                               active_storage/blobs/redirect#show
#                 rails_service_blob_proxy GET    /user-attachments/blobs/proxy/:signed_id/*filename(.:format)                                  active_storage/blobs/proxy#show
#                                          GET    /user-attachments/blobs/:signed_id/*filename(.:format)                                        active_storage/blobs/redirect#show
#                rails_blob_representation GET    /user-attachments/representations/redirect/:signed_blob_id/:variation_key/*filename(.:format) active_storage/representations/redirect#show
#          rails_blob_representation_proxy GET    /user-attachments/representations/proxy/:signed_blob_id/:variation_key/*filename(.:format)    active_storage/representations/proxy#show
#                                          GET    /user-attachments/representations/:signed_blob_id/:variation_key/*filename(.:format)          active_storage/representations/redirect#show
#                       rails_disk_service GET    /user-attachments/disk/:encoded_key/*filename(.:format)                                       active_storage/disk#show
#                update_rails_disk_service PUT    /user-attachments/disk/:encoded_token(.:format)                                               active_storage/disk#update
#                     rails_direct_uploads POST   /user-attachments/direct_uploads(.:format)                                                    active_storage/direct_uploads#create
#                                marksmith        /marksmith                                                                                    Marksmith::Engine
#
# Routes for MissionControl::Jobs::Engine:
#                      Prefix Verb   URI Pattern                                                    Controller#Action
#     application_queue_pause DELETE /applications/:application_id/queues/:queue_id/pause(.:format) mission_control/jobs/queues/pauses#destroy
#                             POST   /applications/:application_id/queues/:queue_id/pause(.:format) mission_control/jobs/queues/pauses#create
#          application_queues GET    /applications/:application_id/queues(.:format)                 mission_control/jobs/queues#index
#           application_queue GET    /applications/:application_id/queues/:id(.:format)             mission_control/jobs/queues#show
#       application_job_retry POST   /applications/:application_id/jobs/:job_id/retry(.:format)     mission_control/jobs/retries#create
#     application_job_discard POST   /applications/:application_id/jobs/:job_id/discard(.:format)   mission_control/jobs/discards#create
#    application_job_dispatch POST   /applications/:application_id/jobs/:job_id/dispatch(.:format)  mission_control/jobs/dispatches#create
#    application_bulk_retries POST   /applications/:application_id/jobs/bulk_retries(.:format)      mission_control/jobs/bulk_retries#create
#   application_bulk_discards POST   /applications/:application_id/jobs/bulk_discards(.:format)     mission_control/jobs/bulk_discards#create
#             application_job GET    /applications/:application_id/jobs/:id(.:format)               mission_control/jobs/jobs#show
#            application_jobs GET    /applications/:application_id/:status/jobs(.:format)           mission_control/jobs/jobs#index
#         application_workers GET    /applications/:application_id/workers(.:format)                mission_control/jobs/workers#index
#          application_worker GET    /applications/:application_id/workers/:id(.:format)            mission_control/jobs/workers#show
# application_recurring_tasks GET    /applications/:application_id/recurring_tasks(.:format)        mission_control/jobs/recurring_tasks#index
#  application_recurring_task GET    /applications/:application_id/recurring_tasks/:id(.:format)    mission_control/jobs/recurring_tasks#show
#                             PATCH  /applications/:application_id/recurring_tasks/:id(.:format)    mission_control/jobs/recurring_tasks#update
#                             PUT    /applications/:application_id/recurring_tasks/:id(.:format)    mission_control/jobs/recurring_tasks#update
#                      queues GET    /queues(.:format)                                              mission_control/jobs/queues#index
#                       queue GET    /queues/:id(.:format)                                          mission_control/jobs/queues#show
#                         job GET    /jobs/:id(.:format)                                            mission_control/jobs/jobs#show
#                        jobs GET    /:status/jobs(.:format)                                        mission_control/jobs/jobs#index
#                        root GET    /                                                              mission_control/jobs/queues#index
#
# Routes for Blazer::Engine:
#            Prefix Verb   URI Pattern                       Controller#Action
#       run_queries POST   /queries/run(.:format)            blazer/queries#run
#    cancel_queries POST   /queries/cancel(.:format)         blazer/queries#cancel
#     refresh_query POST   /queries/:id/refresh(.:format)    blazer/queries#refresh
#    tables_queries GET    /queries/tables(.:format)         blazer/queries#tables
#    schema_queries GET    /queries/schema(.:format)         blazer/queries#schema
#      docs_queries GET    /queries/docs(.:format)           blazer/queries#docs
#           queries GET    /queries(.:format)                blazer/queries#index
#                   POST   /queries(.:format)                blazer/queries#create
#         new_query GET    /queries/new(.:format)            blazer/queries#new
#        edit_query GET    /queries/:id/edit(.:format)       blazer/queries#edit
#             query GET    /queries/:id(.:format)            blazer/queries#show
#                   PATCH  /queries/:id(.:format)            blazer/queries#update
#                   PUT    /queries/:id(.:format)            blazer/queries#update
#                   DELETE /queries/:id(.:format)            blazer/queries#destroy
#         run_check GET    /checks/:id/run(.:format)         blazer/checks#run
#            checks GET    /checks(.:format)                 blazer/checks#index
#                   POST   /checks(.:format)                 blazer/checks#create
#         new_check GET    /checks/new(.:format)             blazer/checks#new
#        edit_check GET    /checks/:id/edit(.:format)        blazer/checks#edit
#             check PATCH  /checks/:id(.:format)             blazer/checks#update
#                   PUT    /checks/:id(.:format)             blazer/checks#update
#                   DELETE /checks/:id(.:format)             blazer/checks#destroy
# refresh_dashboard POST   /dashboards/:id/refresh(.:format) blazer/dashboards#refresh
#        dashboards POST   /dashboards(.:format)             blazer/dashboards#create
#     new_dashboard GET    /dashboards/new(.:format)         blazer/dashboards#new
#    edit_dashboard GET    /dashboards/:id/edit(.:format)    blazer/dashboards#edit
#         dashboard GET    /dashboards/:id(.:format)         blazer/dashboards#show
#                   PATCH  /dashboards/:id(.:format)         blazer/dashboards#update
#                   PUT    /dashboards/:id(.:format)         blazer/dashboards#update
#                   DELETE /dashboards/:id(.:format)         blazer/dashboards#destroy
#              root GET    /                                 blazer/queries#home
#
# Routes for Marksmith::Engine:
#            Prefix Verb URI Pattern                  Controller#Action
# markdown_previews POST /markdown_previews(.:format) marksmith/markdown_previews#create

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

class FulfillerConstraint
  def self.matches?(request)
    return false unless request.session[:user_id]

    user = User.find_by(id: request.session[:user_id])
    user&.fulfiller_perms?
  end
end

class ShopkeeperConstraint
  def self.matches?(request)
    return false unless request.session[:user_id]

    user = User.find_by(id: request.session[:user_id])
    user&.shopkeeper_perms?
  end
end

class ShopItemViewConstraint
  def self.matches?(request)
    return false unless request.session[:user_id]

    user = User.find_by(id: request.session[:user_id])
    user&.shopkeeper_perms? || user&.fulfiller_perms?
  end
end

class HcbIntegrationAdminConstraint
  def self.matches?(request)
    return false unless request.session[:user_id]

    user = User.find_by(id: request.session[:user_id])
    user&.admin? && user&.hcb_integration_enabled?
  end
end

Rails.application.routes.draw do
  post "/slack/commands", to: "slack_commands#handle"
  resources :guild_signups, only: [ :new, :create ]
  post "guild_signups/signup", to: "guild_signups#signup", as: :guild_signups_signup
  post "guild_signups/verify", to: "guild_signups#verify", as: :guild_signups_verify
  get "guild_signups/success", to: "guild_signups#success", as: :guild_signups_success

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

  get "countdown" => "countdown#index", as: :countdown
  get "sorry" => "sorry#index", as: :sorry
  get "adult" => "adult#index", as: :adult

  # Referral system
  get "r/:id" => "referral#show", as: :referral

  # map data for guilds
  get "guilds/map_data", to: "guilds#map_data"

  # Guilds dashboards
  get "guilds/dashboard", to: "guilds#dashboard", as: :guild_dashboard
  post "guilds/dashboard/announce", to: "guilds#create_announcement", as: :guild_create_announcement
  delete "guilds/dashboard/announce", to: "guilds#delete_announcement", as: :guild_delete_announcement
  delete "guilds/dashboard/leave", to: "guilds#leave_guild", as: :guild_leave
  post "guilds/dashboard/close_signups", to: "guilds#close_signups", as: :guild_close_signups
  post "guilds/dashboard/reopen_signups", to: "guilds#reopen_signups", as: :guild_reopen_signups
  post "guilds/dashboard/dismiss_notice/:key", to: "guilds#dismiss_notice", as: :guild_dismiss_notice

  # Authentication
  get "auth/login" => "auth#index", as: :login
  get "auth/slack" => "auth#new", as: :slack_login
  get "auth/github" => "auth#github", as: :github_login
  get "auth/hca" => "auth#new_hca", as: :hca_login
  get "auth/slack/callback" => "auth#create", as: :slack_callback
  get "auth/github/callback" => "auth#create_github", as: :github_callback
  get "auth/hca/callback" => "auth#create_hca", as: :hca_callback
  post "auth/email" => "auth#create_email", as: :login_email
  delete "auth/logout" => "auth#destroy", as: :logout
  post "auth/track" => "auth#track", as: :auth_tracks
  get "auth/idv" => "auth#idv", as: :idv
  get "auth/idv/start" => "auth#idv_start", as: :idv_start
  get "idv_callback" => "auth#idv_callback", as: :idv_callback
  get "auth/age" => "auth#age", as: :age_verification
  post "auth/age" => "auth#submit_age"

  # HCB OAuth (restricted to integration admin)
  constraints HcbIntegrationAdminConstraint do
    get "auth/hcb" => "hcb_oauth#start", as: :hcb_oauth
    get "auth/hcb/callback" => "hcb_oauth#callback", as: :hcb_callback
    delete "auth/hcb" => "hcb_oauth#disconnect", as: :hcb_disconnect
  end

  get "/utm_source" => "landing#utm_source", as: :utm_source
  get "/utm_source=feedback-email" => "landing#utm_source", as: :utm_source_feedback_email
  get "/amd" => "amd#index", as: :amd

  get "home" => "home#index", as: :home

  get "api/site" => "api#site", as: :api_site
  post "api/stickers" => "api#stickers", as: :api_stickers
  post "api/report_grant_given" => "api#report_grant_given", as: :api_report_grant_given
  post "api/report_free_stickers_claimed" => "api#report_free_stickers_claimed", as: :api_report_free_stickers_claimed
  get "api/unfinished_projects" => "api#unfinished_projects", as: :api_unfinished_projects
  post "api/privacy/delete" => "privacy#delete", as: :api_privacy_delete
  post "api/privacy/export" => "privacy#export", as: :api_privacy_export

  resources :projects, only: [ :index, :new, :create, :show, :edit, :update, :destroy ] do
    member do
      get :ship
      post :follow
      post :unfollow
    end
    resources :journal_entries, only: [ :create, :destroy, :show, :edit, :update ] do
      get :export, on: :collection
    end
    resources :kudos, only: [ :create, :destroy ]

    post :check_github_repo, on: :collection
    post :check_bom, on: :collection
    post :check_readme, on: :collection
    get :list_repos, on: :collection
  end
  get "explore" => "projects#explore", as: :explore
  get "stats" => "stats#index", as: :stats
  get "leaderboard" => "leaderboards#index", as: :leaderboard

  get "guilds" => "guilds#index", as: :guilds
  get "guilds/invite/:slug", to: "guild_invites#show", as: :guild_invite
  post "guilds/invite/:slug/signup", to: "guild_invites#signup", as: :guild_invite_signup
  post "guilds/invite/:slug/verify", to: "guild_invites#verify", as: :guild_invite_verify
  post "guilds/invite/:slug/accept", to: "guild_invites#accept", as: :accept_guild_invite
  get "guilds/invite/:slug/success", to: "guild_invites#success", as: :guild_invite_success

  get "toolbag" => "toolbag#index", as: :toolbag

  get "users/me", to: "users#me", as: :me
  resources :users, only: [ :show ] do
    post :invite_to_slack, on: :collection
    post :mcg_check, on: :collection
    post :update_timezone, on: :collection
    post :toggle_pro, on: :collection
  end

  # Team
  get "team", to: "team#index", as: :team

  # About
  get "about", to: "markdown#about", as: :about
  get "about/*slug", to: "markdown#about"
  # Backwards compatibility
  get "docs", to: "markdown#docs", as: :docs
  get "docs/*slug", to: "markdown#docs"

  # Resources
  get "resources", to: "markdown#resources", as: :resources
  get "resources/*slug", to: "markdown#resources",
      constraints: { slug: /[a-z0-9\/_\-]+/ }
  # Backwards compatibility
  get "guides", to: "markdown#guides", as: :guides
  get "guides/*slug", to: "markdown#guides"

  # Starter Projects
  get "starter-projects", to: "markdown#starter_projects", as: :starter_projects
  get "starter-projects/*slug", to: "markdown#starter_projects"

  get "hackpad", to: "markdown#hackpad", as: :hackpad
  get "hackpad/*slug", to: "markdown#hackpad"

  get "faq", to: "markdown#faq", as: :faq

  get "prototype", to: "prototype#index", as: :prototype

  resources :posters, only: [ :show ]

  resources :packages, only: [] do
    get :customs_receipt, on: :member
  end

  namespace :admin do
    post "stop_impersonating", to: "users#stop_impersonating"

    constraints AdminConstraint do
      mount MissionControl::Jobs::Engine, at: "jobs"
      mount Flipper::UI.app(Flipper), at: "flipper"
      mount Blazer::Engine, at: "blazer"

      post "invalidate_privileged_sessions", to: "static_pages#invalidate_privileged_sessions"

      resource :pirate_ship_import, only: [ :new, :create ], controller: "pirate_ship_imports" do
        post :preview
      end

      resources :projects, only: [ :index, :show ] do
        post :delete, on: :member
        post :revive, on: :member
        post :mark_viral, on: :member
        post :unmark_viral, on: :member
        post :toggle_unlisted, on: :member
        post :switch_review_phase, on: :member
        post :force_fix_review_status, on: :member
      end
      resources :allowed_emails, only: [ :index, :create, :destroy ]

      resources :users, only: [ :index, :show ] do
        post :grant_admin, on: :member
        post :revoke_admin, on: :member
        post :grant_reviewer, on: :member
        post :revoke_reviewer, on: :member
        post :grant_fulfiller, on: :member
        post :revoke_fulfiller, on: :member
        post :grant_shopkeeper, on: :member
        post :revoke_shopkeeper, on: :member
        post :revoke_to_user, on: :member
        post :grant_submission_bypass, on: :member
        post :revoke_submission_bypass, on: :member
        post :impersonate, on: :member
        post :ban, on: :member
        post :unban, on: :member
        post :add_ticket_adjustment, on: :member
      end

      resources :hcb_transactions, only: [ :index ]

      resources :shop_items, only: [ :destroy ]
    end

    constraints ReviewerConstraint do
      get "/" => "static_pages#index", as: :root

      resources :guilds, only: [ :index, :show ]

      get "design_reviews", to: "design_reviews#index", as: :design_reviews
      get "design_reviews/next(/:ysws_type)", to: "design_reviews#show_next", as: :next_design_review
      get "design_reviews/:id", to: "design_reviews#show", as: :design_review
      post "design_reviews/:id", to: "design_reviews#create", as: :design_review_create

      get "build_reviews", to: "build_reviews#index", as: :build_reviews
      get "build_reviews/next(/:ysws_type)", to: "build_reviews#show_next", as: :next_build_review
      get "build_reviews/:id", to: "build_reviews#show", as: :build_review
      post "build_reviews/:id", to: "build_reviews#create", as: :build_review_create
      post "build_reviews/:id/promote_first_pass", to: "build_reviews#promote_first_pass", as: :promote_first_pass_build_review
      post "build_reviews/:id/deny_first_pass", to: "build_reviews#deny_first_pass", as: :deny_first_pass_build_review

      get "ai_reviews", to: "ai_reviews#index", as: :ai_reviews
      get "ai_reviews/:id", to: "ai_reviews#show", as: :ai_review
      post "ai_reviews/:project_id", to: "ai_reviews#create", as: :ai_review_create

      resources :projects, only: [ :index, :show ]
      resources :users, only: [ :index, :show, :update ] do
        patch :update_internal_notes, on: :member
      end
    end

    constraints FulfillerConstraint do
      resources :shop_orders, only: [ :index, :show ] do
        post :approve, on: :member
        post :reject, on: :member
        post :hold, on: :member
        post :fulfill, on: :member
        patch :update_notes, on: :member
      end
    end

    constraints ShopkeeperConstraint do
      resources :shop_items, only: [ :new, :create, :edit, :update ]
    end

    constraints ShopItemViewConstraint do
      resources :shop_items, only: [ :index, :show ]
    end
  end
end
