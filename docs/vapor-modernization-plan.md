# Vapor Modernization Plan

Bringing `medo-delirio-api` up to current Vapor 4 / Swift 6 standards without breaking the production API.

**Baseline (Oct 2026):** Vapor 4.122, Fluent 4.13, FluentSQLiteDriver 4.9, APNS 3.0, FeedKit 9.1, Swift 6.4 toolchain.

Already modern before this plan started: async `@main` entrypoint using `Application.make` / `execute` / `asyncShutdown`, all 34 migrations are `AsyncMigration`, secrets come from environment variables, and tests use `Application.make(.testing)`.

## Status

| Phase | What | Status |
|---|---|---|
| 1 | Swift 6 language mode and `Sendable` cleanup | ✅ Done, observed in production Oct 12–26 |
| 2 | Background jobs: async RSS fetch, cancellable `Task` loops | 🚀 Implemented, awaiting deploy |
| 3 | Convert the remaining `EventLoopFuture` handlers to `async`/`await` | ⏳ |
| 4 | Optional cleanups: `RouteCollection`, Swift Testing, explicit JWTKit dependency | ⏳ |
| 5 | Move admin passwords out of URL paths (breaking API change) | 💬 Needs an app-side plan |

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
- [ ] After deploy, watch one full RSS cycle (20 min) and one Friday send.

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
| `StatisticsController` | 59 | Share, play and episode rankings |
| `ReactionsController` | 10 | ❌ none |
| `AuthorsController` | 5 | ❌ none |
| `UpdateEventsController` | 5 | ❌ none |
| `MusicGenresController` | 3 | ❌ none |
| `SongsController` | 2 | ❌ none |
| `SoundsController` | 2 | ✅ `SoundsControllerTests` |
| `StatusCheckController` | 1 | ❌ none |

**Approach:**

- Convert one controller per commit. Change `.flatMap` / `.map` chains to `try await`, and replace `req.eventLoop.makeSucceededFuture(x)` with `x`.
- **Before converting a controller without coverage, add a request-level test** that pins its current JSON response. Authors, update events, songs, sounds and music genres drive the app's content sync, so a changed response shape breaks the app for every user.
- Watch for subtle behaviour differences:
  - Errors thrown inside `flatMapThrowing` versus `Abort` statuses.
  - The order of side effects, such as writes that used to run concurrently and now run one after another.
  - `UpdateEventPushMiddleware` firing on saves.
- Do `StatisticsController` last. It is the largest file (about 2,800 lines) and has active feature work, so convert it in small batches between feature commits.

**Risk:** low to medium. This is mechanical work and tests can verify it, as long as tests are written first.

---

## Phase 4: Optional cleanups

None of these change behaviour. Do them when convenient.

- **Declare JWTKit explicitly.** `ReleaseConfigs.swift` imports `JWTKit`, but it is only available through APNS. Add `.package(url: "https://github.com/vapor/jwt-kit.git", from: "4.13.0")` and the `JWTKit` product to the `App` target.
- **`RouteCollection`.** All 141 routes are registered by hand in `routes.swift`. Make each controller conform to `RouteCollection` and register its own routes under `api/v1`, `api/v2` and `api/v3` groups. Keep every path identical; an existing-routes test helps.
- **Swift Testing.** Move from `XCTVapor` + `XCTestCase` to `VaporTesting` + `@Test`, starting with new tests. Existing XCTest suites can stay as they are.
- **Package layout.** The current Vapor template uses a single `executableTarget` instead of the `App` + `Run` split, and drops the `-cross-module-optimization` `unsafeFlags`. This is cosmetic; only change it alongside a release-build benchmark.

---

## Phase 5: Passwords in URL paths (needs a decision)

59 lines in `routes.swift` register admin routes with a `:password` path parameter, for example `set-donor-names/:password`. Passwords in URLs end up in access logs, reverse-proxy logs and shell history.

**Proposal:**

1. Accept the password from an `Authorization: Bearer …` header **in addition to** the path parameter, through a small middleware on an admin route group.
2. Update the clients that call these routes: admin tooling, scripts and the app if applicable.
3. After a transition period, remove the path-parameter variants.

This is a breaking API change, so it needs coordination with whatever calls these endpoints. It should not ship together with any other phase.
