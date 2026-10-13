# Privacy requests (deletion and export)

Deletion and export requests come from the Hack Club privacy hub. The hub calls `delete` once with `dry_run: true`, staff review the counts, and after approval the hub calls again with `dry_run: false`.

| Endpoint | Does |
| --- | --- |
| `POST /api/privacy/delete` | Deletes everything belonging to the person, or reports what it would delete on a dry run |
| `POST /api/privacy/export` | Reports what is held. It always runs as a dry run, so it never changes anything |

## Authentication

Each call carries `Authorization: Bearer <token>`, an ES256 JWT signed by the hub. `PrivacyToken` verifies it with the `jwt` gem against the hub's JWKS at `https://yeet.hackclub.com/.well-known/jwks.json` (override with `PRIVACY_JWKS_URL`).

The verifier checks:

- the signature against the key named by `kid`, accepting only `alg: ES256` and `typ: JWT`
- `iss` is `hackclub-privacy` and `aud` is exactly `blueprint`
- `exp` and `iat` with 30 seconds of leeway, and `exp - iat` is at most 300 seconds
- `action` matches the endpoint
- `jti` has not been seen before

Keys are cached for 5 minutes and refetched (at most every 30 seconds) when an unknown `kid` shows up, so key rotation on the hub needs no change here.

Each `jti` is recorded in `privacy_token_uses` before any work starts, and rows older than a day are pruned by the `prune_privacy_token_uses` recurring task.

The person is found only from the token's `subject` claims, never the request body or query string:

- `emails`, matched case-insensitively against `users.email`, the `+old` emails left behind by `DuplicateUserMerger`, and `guild_signups.email`
- `slack_id`, matched against `users.slack_id`
- `identity_id`, matched against `users.identity_vault_id`

The response is `200 {request_id, found, dry_run, deleted: {table: rows}, retained: [{type, count, reason}]}`. Once someone is deleted, later calls answer `found: false`.

Errors:

| Status | Error | When |
| --- | --- | --- |
| 401 | `invalid_token` | Missing, malformed, expired, or wrongly signed token |
| 400 | `action_mismatch` | A delete token sent to `/export`, or the reverse |
| 409 | `replayed` | The `jti` was already used |
| 409 | `manual_review_required` | See below |
| 503 | `jwks_unavailable` | The hub's keys can't be fetched (the hub retries) |
| 503 | `storage_unavailable` | R2 or Gorse couldn't be reached during a real deletion (the hub retries) |
| 500 | `internal_error` | Anything else (the hub retries) |

Only the `request_id`, the action, and the outcome are logged. Tokens, emails, Slack IDs, and identity IDs never reach the logs or the response.

## Needs a human

`PrivacyDeletion` refuses with `409 manual_review_required` and changes nothing if a matched account:

- is an admin, reviewer, fulfiller, or shopkeeper
- has the HCB integration enabled, because it holds the program's HCB OAuth tokens
- organizes a guild that isn't closed, because removing them changes the guild's status and Slack channel for its attendees

## How a run works

The dry run and the real run share one code path. `PrivacyDeletion` does the whole deletion inside a transaction, counting rows as it goes. On a dry run (and on every export) it then rolls back. On a real run it deletes the external copies (R2 files, Gorse entries, Airtable guild signups) before committing. If R2 or Gorse can't be reached the transaction rolls back and returns `503`, so the retry still finds the person. Airtable delete failures are logged by `AirtableSync.delete_record!` and don't block the deletion.

Rows are removed with `delete_all` and `update_all`, so model callbacks (Slack, Airtable, Gorse, emails) never fire during a dry run.

## What gets deleted

- **Account data:** guild signups, task list, privileged session expiry, recommendations, and ahoy visits and events
- **Content:** journal entries they wrote or that sit on their projects, kudos and follows they gave or received, unique project views, timeline items, and AI reviews of their projects
- **Projects:** every project with no reviews, grants, or packages
- **Uploads:** banners, demo pictures, cart screenshots, journal attachments, and images embedded in journal or project markdown, with their variants. The R2 objects are deleted on the real run, before commit
- **Email-keyed rows:** one-time passwords, email tracks, and allowed emails, matched against the token's emails and the account's email
- **Audit rows:** paper_trail versions of their user, projects, session expiry, and allowed emails. `whodunnit` pointing at them is cleared
- **Bookkeeping:** Flipper actor gates and Airtable sync rows for deleted records
- **External copies:** the Gorse user and its project and journal items, and their Airtable guild signup records

Other people's numbers are fixed in the same transaction: `kudos_count` and `journal_entries_count` are recounted, `views_count` is decremented on projects they viewed, and their ID is removed from `journal_entries.views`. Review claims they held are released.

## What gets kept

Kept rows are anonymized in place and reported in `retained`:

| Kept | How | Why |
| --- | --- | --- |
| User row | Email becomes `deleted-<id>@deleted.invalid`. Username, avatar, Slack ID, timezone, GitHub fields, identity vault ID and tokens, birthday, IDV country, internal notes, and activity timestamps are wiped. Ban status and referrer are kept | Orders, reviews, grants, and ticket adjustments reference it |
| Reviewed, funded, or shipped projects | Title becomes "Deleted project". Description, links, Hackatime keys, and files are wiped, and the project is marked deleted and unlisted | Reviews, grants, and packages reference them |
| Design and build reviews | Unchanged | They back funding and ticket decisions and reviewer stats |
| Project grants | Unchanged | Record of money granted |
| Manual ticket adjustments | Unchanged | Ticket ledger |
| Shop orders | Address, phone number, and tracking number wiped. Pending, awaiting verification, and on hold orders are rejected with "Account deleted" | Accounting and fulfilment |
| Packages | Recipient name, email, address, and tracking number wiped | Postage cost accounting |

## Not handled here

- **HCB:** `hcb_grants` and `hcb_transactions` are a ledger mirrored from HCB, linked by display name only, and are left alone
- **Airtable:** the users, projects, and shop orders tables are filled by the bulk sync, so the next scheduled sync overwrites them with the anonymized values. Whether rows for deleted projects disappear depends on that Airtable sync's settings
- **Elsewhere:** Slack, Hackatime, Loops, Hack Club Auth, Sentry, and the `JOURNAL.md` in the person's own GitHub repo are handled by their own systems or the hub's other targets
- **Short-lived data:** Solid Queue jobs and Solid Cache entries expire on their own
