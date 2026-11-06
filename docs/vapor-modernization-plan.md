# Vapor Modernization Plan

Bringing `medo-delirio-api` up to current Vapor 4 / Swift 6 standards without breaking the production API.

**Baseline (Oct 2026):** Vapor 4.122, Fluent 4.13, FluentSQLiteDriver 4.9, APNS 3.0, FeedKit 9.1, Swift 6.4 toolchain.

Already modern before this plan started: async `@main` entrypoint using `Application.make` / `execute` / `asyncShutdown`, all 34 migrations are `AsyncMigration`, secrets come from environment variables, and tests use `Application.make(.testing)`.

## Status

| Phase | What | Status |
|---|---|---|
| 1 | Swift 6 language mode and `Sendable` cleanup | ✅ Done, observed in production Oct 12–26 |
| 2 | Background jobs: async RSS fetch, cancellable `Task` loops | ✅ Done, observed in production Oct 26 – Nov 1 |
| 3 | Convert the remaining `EventLoopFuture` handlers to `async`/`await` | ✅ Done in code Nov 1–2; production check pending for the last batches |
| 4 | Optional cleanups: `RouteCollection`, Swift Testing, explicit JWTKit dependency, package layout | ✅ Done in code Nov 2–6 |
| 5 | Move admin passwords out of URL paths (breaking API change) | 📋 Planned Nov 6: callers mapped, MedoHelper only |

---

## Phase 1: Swift 6 language mode ✅

Commits:

- `519d424` Mark Fluent models as `@unchecked Sendable`
- `a71d785` Discard the weekly highlights result in the scheduled task
- `3a40188` Adopt the Swift 6 language mode

What changed:

- **24 Fluent models** now declare `@unchecked Sendable`. Vapor recommends this for Fluent models because they are mutable classes with property wrappers. It only affects compilation. No model instance is stored in shared state; they are created per request.
- **`ExternalLink`** changed from `final class` to `struct`. It isn't used anywhere else.
- **`WeeklyHighlightsLifecycle`** now writes `_ = await service.sendWeeklyHighlights()`. The function keeps its warning for unused results, because the manual route uses the result.
- **`Package.swift`:**
  - `swift-tools-version` 5.10 → 6.0, which enables Swift 6 mode.
  - macOS 12 → 13.
  - Dependency minimums raised from `4.0.0` to the versions we build against.
  - `Package.resolved` did not change.
- **Shared ISO 8601 formatters** in `Date+.swift` and `ElectionLiveUsageSeries.swift` are marked `nonisolated(unsafe)`. They are configured once and never mutated. They were deliberately *not* replaced with `ISO8601FormatStyle`, because their strings are stored in SQLite and compared as text.
- **`WeeklyHighlightsService.brtDateFormatter`** changed from `static var` to `static let`. `DateFormatter` is already `Sendable`.
- **`ReleaseConfigs.swift`** now uses `@preconcurrency import JWTKit`, because jwt-kit 4 does not mark its types as `Sendable`.

Result: the build has no warnings or errors in project code, and all 134 tests pass.

### Deploy checklist

- [x] The production build environment uses **Swift 6.0 or newer**. The server has Swift 6.3.3, installed with swiftly.
- [x] The release build succeeds on the server: `swift build -c release` took 138 s with Swift 6.3.3 on Linux.
- [x] Deployed on 2026-10-12. The server moved from `31148b4` to `3a40188`, so `3a40188` was the only new commit in this deploy.

### What to watch during the observation week

Phase 1 is expected to change almost nothing at runtime: the Sendable annotations only matter to the compiler, and the formatters and date strings are unchanged. Swift 6 mode does add runtime actor-isolation checks. The project has no `@MainActor` code, only plain actors (`ElectionLiveStore`, `EventIdWrapper`, `ContentUpdatePushService`, `APNsProviderToken`), so a crash from these checks is unlikely. That is still the main runtime change to watch for.

- [ ] **Startup logs:** look for "RSS polling scheduled every 20 minutes", "Weekly highlights scheduled every Friday at 18:00 BRT…", and the election polling line if it is enabled.
- [ ] **No crashes or restarts.** Search the logs for `Incorrect actor executor assumption` or other Swift runtime traps.
- [ ] **Content sync:** the app still downloads new sounds, songs, authors and update events. `dateTime` and `dateAdded` strings still look like `2026-10-12T21:00:00.000Z`.
- [ ] **Push notifications:**
  - At least one push is delivered, either a new-episode push or a content update push. This exercises the APNS JWT configuration in `ReleaseConfigs.Push`.
- [ ] **RSS polling:** "RSS poll: checking feed…" appears every 20 minutes, and new episodes are detected.
- [ ] **Weekly highlights:** sent on **Friday at 18:00 BRT**. Check that a `WeeklyHighlightLog` row is written for that day.
- [ ] **Statistics and rankings endpoints** respond as before. These include the share, play and episode rankings.
- [ ] **Election endpoints and the usage series**, if election polling is enabled.

### Rollback

All three commits can be reverted independently and none of them touch the database schema:

```bash
git revert 3a40188 a71d785 519d424
```

To roll back only the toolchain requirement, reverting `3a40188` is enough. The other two commits compile fine under Swift 5.10.

---

## Phase 2: Background jobs

**Why:** `RSSPollingService.checkForNewEpisode()` calls `FeedParser(URL:).parse()`, which is a **blocking** network request. That's why `RSSPollingLifecycle` runs it on `DispatchQueue.global`. Separately, `RSSPollingLifecycle` and `WeeklyHighlightsLifecycle` use `eventLoop.scheduleRepeatedTask`, start a `Task {}` that is never cancelled, and are not stopped on shutdown. `ElectionPollingLifecycle` already uses the better pattern.

**Changes:**

1. **RSS fetch:**
   - Download the feed with `app.client.get(feedURL)`, which uses async AsyncHTTPClient.
   - Parse the body with `FeedParser(data:)`. This needs no FeedKit upgrade; FeedKit 10 also offers an async API if we upgrade later.
   - Make `checkForNewEpisode()` `async` and remove the inner unstructured `Task`, so processing the episode and syncing episodes happen in order inside the job.
2. **Lifecycles:** rewrite `RSSPollingLifecycle` and `WeeklyHighlightsLifecycle` in the style of `ElectionPollingLifecycle`:
   - Each runs one long-lived `Task` that loops with `try await Task.sleep(for:)`.
   - The task is stored and cancelled in `shutdown` (or use `didBootAsync` / `shutdownAsync`).
   - Remove the `DispatchQueue` and `scheduleRepeatedTask` usage.
3. **Weekly highlights timing:** recompute "next Friday 18:00 BRT" on every iteration instead of adding a fixed 7-day interval. A fixed interval drifts if the job takes time, and is wrong if a timezone rule ever changes.

**Risk:** medium. These jobs send push notifications to every user, so a bug can double-send or skip a send.

**Safeguards already in place:**
- The new-episode cooldown in `LastKnownEpisode`.
- `WeeklyHighlightLog` records each send to prevent duplicates.
- Each job can be turned off with an env flag: `RSS_POLLING_ENABLED` and `WEEKLY_HIGHLIGHTS_ENABLED`.

**Verification:**
- [x] Unit tests for parsing the feed from `Data` (`RSSPollingServiceTests`). They use inline Spreaker-shaped XML instead of a fixture file and cover a valid feed, too few items, a latest item without a GUID, and invalid XML.
- [x] Unit tests for the "next Friday 18:00 BRT" calculation (`WeeklyHighlightsScheduleTests`), covering just before and just after 18:00 on a Friday and a server clock in UTC.
- [x] One-off check of the full poll against the live feed in the testing environment (in-memory database, no push): 901 episodes synced, and a second run correctly found nothing new.
- [x] After deploy (`fde8909`, Oct 26): the first poll ran 6 s after boot, the next one exactly 20 minutes later, and the Friday weekly highlights and new-episode notifications went out as usual.

**What was done (Oct 26):**

- **RSS fetch:** `checkForNewEpisode()` is `async`. It downloads the feed with `app.client` (30 s timeout) and parses it with `FeedParser(data:)` on `app.threadPool`. The parse takes ~0.1 s on a Mac and longer on the Nanode, and with 1 CPU the concurrency pool has a single thread, so blocking work stays off it.
- **Parse output:** `parseFeed` maps FeedKit items into a `Sendable` `FeedEpisode` struct, so FeedKit types don't spread into the sync code.
- **Polls run one after another:** processing the episode and syncing episodes happen in order inside the poll. The next 20-minute wait starts only after a poll finishes. This also closes a latent double-send: before, if sending new-episode pushes (0.5 s per device) took longer than 20 minutes, the next poll could see the old GUID still in the database and notify everyone again.
- **Lifecycles:** `RSSPollingLifecycle` and `WeeklyHighlightsLifecycle` follow the `ElectionPollingLifecycle` pattern: one stored `Task`, cancelled in `shutdown`. The `DispatchQueue` and `scheduleRepeatedTask` usage is gone.
- **Weekly highlights:** the next Friday 18:00 BRT is recomputed before every wait, and the "next run in …" line is logged each time. The 60-second minimum wait stays, and the existing once-per-day guard in `sendWeeklyHighlights` still prevents duplicate sends.
- **Not done:** `PushBroadcastController` also starts a `Task {}` that isn't cancelled on shutdown. Its state lives in memory and is lost on restart anyway, so cancelling it wouldn't change much. Left as is.

---

## Phase 3: `EventLoopFuture` → `async`/`await`

About 87 `EventLoopFuture` usages remain in 8 controllers:

| Controller | `EventLoopFuture` | Test coverage |
|---|---|---|
| `StatisticsController` | ~~59~~ ✅ 0 | ✅ In 9 batches, Nov 1–2: batch 1 (sound share rankings, device counts), batch 2 (song share and episode play charts), batch 3 (posting share stats and bundle ids), batch 4 (reaction stats), batch 5 (active users and sessions), batch 6 (device, model and iOS version analytics), batch 7 (navigation and app version analytics), batch 8 (episode, share clip and chapter analytics), batch 9 (Retro 2025, tested on test-registered routes since its routes are off) |
| `ReactionsController` | ~~10~~ ✅ 0 | ✅ `ReactionsControllerTests` (converted Nov 1) |
| `AuthorsController` | ~~5~~ ✅ 0 | ✅ `AuthorsControllerTests`, every handler (converted Nov 1) |
| `UpdateEventsController` | ~~5~~ ✅ 0 | ✅ `UpdateEventsControllerTests` (converted Nov 1) |
| `MusicGenresController` | ~~3~~ ✅ 0 | ✅ `MusicGenresControllerTests` (converted Nov 1) |
| `SongsController` | ~~2~~ ✅ 0 | ✅ `SongsControllerTests` (converted Nov 1) |
| `SoundsController` | ~~2~~ ✅ 0 | ✅ `SoundsControllerTests` (converted Nov 1) |
| `StatusCheckController` | ~~1~~ ✅ 0 | ✅ `StatusCheckControllerTests` (converted Nov 1) |

**Approach:**

- Convert one controller per commit. Change `.flatMap` / `.map` chains to `try await`, and replace `req.eventLoop.makeSucceededFuture(x)` with `x`.
- **Before converting a controller without coverage, add a request-level test** that pins its current JSON response. Authors, update events, songs, sounds and music genres drive the app's content sync, so a changed response shape breaks the app for every user.
- Watch for subtle behaviour differences:
  - Errors thrown inside `flatMapThrowing` versus `Abort` statuses.
  - The order of side effects, such as writes that used to run concurrently and now run one after another.
  - `UpdateEventPushMiddleware` firing on saves.
- Do `StatisticsController` last. It is the largest file (about 2,800 lines) and has active feature work, so convert it in small batches between feature commits.

**Risk:** low to medium. This is mechanical work and tests can verify it, as long as tests are written first.

**What was done (Nov 1–2):** no `EventLoopFuture` code is left in `Sources/App`. Every controller or batch landed as two commits: tests that pin the old behaviour, then the conversion. The suite now has 324 tests.

- **SQL injection fixed, three places:**
  - `active-users-count-from/:date` and `sessions-count-from/:date` (behind the analytics password). Live in production.
  - The Retro 2025 routes. These are off, so they weren't exposed.
  - In each case a test showed an injected date reading every row on the old code.
- **Every query now binds its values.** This includes dates that were already validated or generated by the server.
- **Queries that used to run concurrently now run one after another.** SQLite serves one query at a time anyway.
- **Quirks pinned by tests, then decided on Nov 2.** Each was checked against the app, MedoHelper and the Oct 28 database copy.
  - **Fixed:** deleted reactions took top-3 slots as empty reactions (on 4 of the last 30 days); they're now left out, and titles may contain parentheses.
  - **Fixed:** top chapters counted every tap ever under MedoHelper's "Últimos 30 dias" header, with an arbitrary title; now 30 days and the latest title.
  - **Fixed:** invalid UUIDs in the content controllers return 400 instead of 500.
  - **Removed:** `install-id-count` (always 500) and `update-events-for-display` (unfinished). Neither had a single request in two weeks of nginx logs, and neither client calls them.
  - **Left as is:** a lowercase `contentId` in share posts would be missed by the charts, but none of the 806,604 stored rows has one.
  - **Left as is:** `total_timezones_count` counts installs that reported a time zone. The name is misleading, but that's the right denominator for MedoHelper's time zone pie.

---

## Phase 4: Optional cleanups

None of these change behaviour. Do them when convenient.

- ✅ **Declare JWTKit explicitly (Nov 6).** `Package.swift` now lists jwt-kit `from: "4.13.0"`, and the `JWTKit` product is in the `App` target.
  - **Why:** `APNsBroadcastClient` signs the broadcast push JWT with it, and `ReleaseConfigs` uses its `JWKIdentifier`.
  - **No version change:** `Package.resolved` is unchanged, still 4.13.5, the version APNSwift was already pulling in.
  - **What it protects against:** an APNS or APNSwift upgrade that stops depending on jwt-kit. Without the declaration, the build would fail with "no such module JWTKit" in the middle of that upgrade; with it, jwt-kit stays and the upgrade goes through.
  - **`@preconcurrency` stays** on the import in `ReleaseConfigs`, because `JWKIdentifier` isn't `Sendable` in jwt-kit 4.
- ✅ **`RouteCollection` (Nov 6).** All 23 controllers register their own routes in `boot(routes:)`, in a `// MARK: - Routes` extension at the end of each file, and `routes.swift` is now just the list of `app.register(collection:)` calls.
  - **Inline closures:** the three closures that lived in `routes.swift` became named handlers. The app site association went to `ShareController`; `send-push-notification` and `test-weekly-highlights-push` went to `NotificationsController`.
  - **Proof nothing moved:** `RoutesTests` pins all 145 routes with their response types, and it passes unchanged before and after.
- ✅ **Swift Testing (Nov 2).** All 327 tests moved from `XCTVapor` + `XCTestCase` to `VaporTesting` + `@Test`, one to one, and `XCTVapor` is gone from `Package.swift`.
  - **App lifecycle:** each test runs inside `withTestApp`, built on Vapor's `withApp`. It shuts the app down even when the test throws.
  - **Parallel by default:** tests now run in parallel, so the suite takes about 5 s instead of 17 s. Each app has its own in-memory database. The password environment variables are set once per process, because `setenv` isn't safe alongside concurrent reads.
  - **Test-only change:** nothing ships to the server.
- ✅ **Package layout (Nov 6).** `Sources/Run` folded into `App`, which is now the single `executableTarget`, as in the current Vapor template. An explicit `.executable(name: "Run", …)` product keeps the binary at `.build/release/Run`, so the systemd unit doesn't change.
  - **`-cross-module-optimization` is gone.** It applied only to `App`, and controlled how much of its code other modules could inline. With a single target nothing imports `App` in release, and the dependencies were never built with it, so it was doing almost nothing.
  - **Measured on a Mac:** incremental release builds stayed at about 15–16 s, and the binary went from 59.95 MB to 59.80 MB.
  - **Booted:** the release binary boots and lists all 145 routes.
  - **On the Nanode:** compare the next deploy's `swift build -c release` time with the 138 s from Phase 1.

---

## Phase 5: Passwords in URL paths (needs a decision)

72 admin routes take their password as a `:password` path segment, for example `POST /api/v3/set-donor-names/:password`. Passwords in URLs end up in nginx access logs, proxy logs and shell history. (The count was 59 when this plan was written; routes added since then, like `retro2026-analytics`, follow the same pattern.)

### Who calls these routes (checked Nov 6)

**The app sends no passwords.** Every match in `MedoDelirioBrasilia` is a public GET on the same path (`v4/dynamic-banner`, `v4/money-info`, `v4/episode-highlight`, …) or a doc comment showing a manual call. Phase 5 does not need an app release.

**MedoHelper calls 52 of them**, all through `Secrets.*Password`:

| Where | Routes |
|---|---|
| `AnalyticsRepository` | 22 analytics GETs (`active-users-*`, `device-*`, `ios-version*`, `navigation-analytics`, `version-*`, `episode-analytics`, `share-clip-analytics`, `chapters-usage-analytics`, `folder-research-analytics`, `watch-pairing-rate`, `election-live-analytics` and `/series`, `games-analytics`, `retro2026-analytics`, `unique-users`) |
| `MedoHelperWidget/WidgetDataFetcher` | `widget-summary`, plus 4 of the analytics GETs above |
| `ContentRepository` | `create-sound`, `create-song`, `update-content`, `DELETE sound/:id`, `DELETE song/:id` |
| Sound, author and genre views | `import-sounds`, `import-songs`, `update-content-file`, `change-update-visibility`, `import-authors`, `create-author`, `update-author`, `DELETE author/:id`, `import-music-genres`, `create-music-genre` |
| `ReactionRepository` | `create-reaction`, `add-sounds-to-reaction`, `PUT reaction`, `delete-all-reactions`, `delete-all-reaction-sounds`, `delete-reaction-sounds/:id`, `delete-reaction/:id` |
| `PushBroadcastRepository` (one `request` helper) | `push-audience`, `GET`/`POST push-broadcasts`, `push-broadcast/:id`, `push-broadcast/:id/cancel` |
| `DonorsRepository`, `DynamicBannerRepository` | `set-donor-names`, `dynamic-banner` |

**20 have no caller in either codebase**, so they're manual calls (curl): `DELETE music-genre/:id`, `sessions-count-from`, `weekly-highlights-stats`, the 4 `election/*` admin routes, `retro-banner` (settings, set, delete), `episode-highlight` (set, delete), `money-info`, `anniversary-banner`, `promo-banner`, `rss-status`, `test-new-episode-push`, `test-weekly-highlights-push`, `repair-share-count-stat-content-types` and `replace-device-model-name`.

`POST /api/v1/send-push-notification` already takes its password in the JSON body, so it isn't part of this. Nothing calls it either.

### Plan

1. **Server, non-breaking.** Add `req.adminPassword`, which reads `Authorization: Bearer <password>` and falls back to the `:password` segment. The 62 handler checks use it instead of `req.parameters.get("password")`, and each handler keeps its current status codes. Every admin route is also registered without the `:password` segment, so old and new URLs both work. A route-shape check found no conflicts with existing routes. Tests: for every admin route, no password and a wrong one are rejected, and the right one is accepted from both the header and the path.
2. **MedoHelper.** Build these URLs without the password and send the header. Most calls go through `APIClient`, `PushBroadcastRepository.request` or `WidgetDataFetcher.get`, so a few helpers cover nearly all 52. Update any curl notes or scripts for the 20 manual routes.
3. **Watch the logs.** Count the remaining old-style calls in nginx without printing them, until they reach zero for a few days.
4. **Server, breaking.** Remove the `:password` variants, then rotate all 7 passwords: the old ones are in up to two weeks of rotated nginx logs, and in shell history.

Each server step deploys alone, not together with any other change.
