# Newtronic Banking — Modernization Plan

## Context

`C:\Users\ASUS\projects\Banking_app` is a Flutter 3.47 / Dart 3.13 banking demo (`newtronic_banking`, ~2,750 lines of Dart across 12 files). It looks finished from the outside, but reading the source shows three separate problems:

1. **The core transfer flow is broken.** In `add_transaction_screen.dart:52-53`, `filteredBanks`/`filteredBalances` are copied from `banks`/`balances` *before* the repository fills them, so both pickers open empty. The account picker never recovers at all — its search handler mutates `tempBalance` instead of `filteredBalances`, and its tap handler is gated behind `if (tempBalance.isNotEmpty)`, so selecting an account is impossible. Several other paths throw `RangeError` (`tempBank[0]` on an empty list, `substring(8, 12)` on short input, `formattedBankNumber` on any digit count not divisible by 4).
2. **There is no design system.** `MaterialApp` declares no `theme:` at all, so the app renders in stock Material 2 blue over a hand-rolled 8-colour palette. No dark mode, no `ColorScheme`, no `TextTheme`, no motion language. `flutter analyze` reports 38 issues: 25 deprecated `withOpacity`, 3 deprecated `WillPopScope`, 6 `use_build_context_synchronously`. `flutter test` fails outright — `test/widget_test.dart` is still the untouched counter template.
3. **Nothing is real.** Balances are strings (`"5,000,000 "`, trailing space), so no arithmetic is possible; transfers never debit anything. Sign-up shows a success animation but creates no user. Login state is lost on restart. `sqflite` is declared but never imported. Two of three home tabs and the whole Autodebit tab are "Coming Soon" Lotties. The QRIS button, the search field on the transaction screen, and "Save as Favorite" are all inert — the last one even navigates home with a hardcoded `arguments: 5`, silently switching the logged-in user.

**Intended outcome:** a Flutter banking app that (a) builds and analyzes clean and passes its tests, (b) runs on a real Material 3 design system with light/dark themes, glass-card surfaces and a consistent motion language, and (c) actually moves money — persisted locally, with spending analytics, favorites, scheduled transfers, QR payment and exportable receipts.

**Decisions confirmed with the user:** all four feature groups in scope · Material 3 + glass cards + dark mode · verify on Chrome and Windows (so persistence must be web-safe — `shared_preferences`, not `sqflite`) · upgrade all dependencies to latest.

**Commits are the user's job.** Every task ends with a clean working tree left uncommitted and unpushed.

---

## Architecture Decisions

| Decision | Rationale |
|---|---|
| **`shared_preferences` + JSON, not `sqflite`** | `sqflite` has no web or Windows support without `sqflite_common_ffi(_web)`. The verification targets are Chrome and Windows. `shared_preferences` works on all six platforms with zero native config. Data volumes here are tiny. Drop the unused `sqflite` dependency. |
| **`provider` (`ChangeNotifier`) for app state** | Today every `FutureBuilder` calls `Repository()` — a fresh instance on every rebuild, re-reading and re-decoding the JSON asset each frame. A few `ChangeNotifier` stores (`SessionStore`, `AccountStore`, `TransactionStore`) give one source of truth, make balances update live after a transfer, and stay far smaller than Bloc/Riverpod for this size. |
| **Money as `int` rupiah, never `String`** | Rupiah has no minor unit in practice. A `Money`-typed `int` plus `formatRupiah()` in `data/utils/formatted.dart` kills the `"5,000,000 "` string-math problem at the root and makes the Tracker charts possible. JSON seed files get migrated to numbers. |
| **Design tokens in `lib/styles/`, theme in `lib/core/theme/`** | `pallet.dart` becomes a token file feeding two `ColorScheme`s; `typography.dart` becomes a `TextTheme` builder. Existing `headline1`…`metadata` names stay as deprecated aliases during the re-skin so screens migrate one at a time instead of in one unreviewable diff. |
| **Seed-then-own data model** | On first launch, the bundled JSON assets seed the local store; after that the local store is authoritative. Keeps the demo's nice sample data while making writes real. |
| **QR scanning is a separate, droppable task** | `qr_flutter` (generation) is pure Dart and works everywhere. `mobile_scanner` (camera scanning) does **not** support Windows. Generation and manual-code entry land first; camera scan is the last task and gets dropped if it breaks the Windows build. |
| **Scheduled transfers run on app open, not in background** | Background scheduling is impossible on web and needs `flutter_local_notifications` (no web support) on mobile. Due transfers are evaluated and applied when the app opens, which is honest, portable, and verifiable. |

### Dependency changes

Add: `provider`, `shared_preferences`, `fl_chart`, `qr_flutter`, `flutter_animate`, `pdf`, `printing`.
Remove: `sqflite` (never imported). Move `flutter_launcher_icons` to `dev_dependencies` (it is a build tool).
Upgrade: `google_fonts` 6→8, `lottie` 2→3, `intl` 0.18→0.20, `cached_network_image` 3→4, `flutter_svg` 2.0.7→2.3, `shimmer` 3→4, `cupertino_icons` 1.0.6→1.0.9, `flutter_lints` 2→6.

`flutter_lints` 6 will surface new lint failures — expected, and cleaned up as part of Task 1.

### Dependency graph

```
Task 1  pubspec + toolchain green
   │
   ├── Task 2  P0 crash/logic fixes ──────────────────┐
   │                                                   │
   ├── Task 3  Design tokens + M3 themes               │
   │      └── Task 4  UI kit (buttons/fields/cards)    │
   │             └── Tasks 5-8  screen re-skins  ◄─────┘
   │
   └── Task 9  Local store + money model
          ├── Task 10  Real auth + session
          ├── Task 11  Real transfers (debit + history)
          │      ├── Task 12  Tracker analytics
          │      ├── Task 13  Favorites + scheduled
          │      └── Task 14  Receipt export (PDF/PNG)
          └── Task 15  QR pay
```

---

## Phase 0 — Make it build, test and analyze clean

### Task 1: Modernize the toolchain and dependencies

**Description:** Upgrade every dependency to latest, drop `sqflite`, add the new packages, and resolve the resulting breaking changes so the project builds on web and Windows. Also create `tasks/plan.md` and `tasks/todo.md` (copies of this plan and its checklist) as the first step, since plan mode could not write into the repo.

**Acceptance criteria:**
- [ ] `tasks/plan.md` and `tasks/todo.md` exist in the repo
- [ ] `pubspec.yaml` has the adds/removes/upgrades listed above; `flutter pub outdated` shows no upgradable direct dependency
- [ ] `flutter analyze` runs to completion (issue count may still be non-zero — Task 2 clears it)

**Verification:**
- [ ] `flutter pub get` succeeds
- [ ] `flutter build web --release` succeeds
- [ ] `flutter build windows --debug` succeeds

**Dependencies:** None · **Files:** `pubspec.yaml`, `analysis_options.yaml`, `tasks/*` · **Scope:** S

### Task 2: Fix every known defect

**Description:** Clear the crash paths, the dead logic, and all 38 analyzer issues. This is deliberately done *before* any redesign so later UI diffs are readable.

**Crashes / dead flows:**
- `add_transaction_screen.dart:52-53` — assign `filteredBanks`/`filteredBalances` *after* the loops populate `banks`/`balances`
- `add_transaction_screen.dart` `customShowAccountLists` — search must rebuild `filteredBalances` (not `tempBalance`); drop the inverted `if (tempBalance.isNotEmpty)` gate that makes selection impossible; delete `tempBalance`
- `add_transaction_screen.dart:~318` — `tempBank[0]['image']!` guards against an empty list; `bankNumberController.text.substring(0,4)` / `substring(8,12)` become length-safe
- `formatted.dart` `formattedBankNumber` — `substring(i, min(i+4, length))`, fixing `RangeError` on any digit count not divisible by 4
- `mounted` guards on all six `use_build_context_synchronously` sites: `splash_screen.dart:16`, `home_screen.dart` (both the `initState` delay and the `setState` loop in `getTransaction`), `add_transaction_screen.dart:494,496`, `status_transaction_screen.dart:191`, `components.dart:183`

**Logic:**
- `authentication_screen.dart` username rule `length < 6 && length > 12` is unsatisfiable — becomes `< 6 || > 12`
- password rule's `A && B || C && D && E` precedence — rewrite as explicit named checks (min length, upper, lower, digit, symbol)
- login success must pop the dialog route before `pushNamed`, and use `pushReplacementNamed` so Home is not stacked on a dead dialog
- `status_transaction_screen.dart` — drop hardcoded `arguments: 5` and the hardcoded `'Rafeh Qazi'` / ref number / `Rp. 2.500` admin fee; carry real values through
- `components.dart` `customTextField` — `onTap: () => onTapTextField` never fires; retype as `VoidCallback?` and call it

**Cleanup:**
- Delete dead code: `components.dart:245` `customDraggableModalBottomSheet` (shadowed and renders one item's image/name for every row), `filterAccounts`, `formattedDate`, `Repository.searchBankByName`, `Repository.getBanksById`
- `WillPopScope` → `PopScope` (3 sites), `withOpacity` → `withValues(alpha:)` (25 sites)
- Home's fixed `MediaQuery.height * .95` panel → flexible layout that does not overflow at 320px or on a tablet
- `test/widget_test.dart` — replace the counter template with a real smoke test that pumps `MyApp` and asserts the splash renders

**Acceptance criteria:**
- [ ] `flutter analyze` reports **0 issues**
- [ ] `flutter test` passes
- [ ] Bank picker and account picker both show a full list the moment they open, and a selection sticks
- [ ] A transfer can be completed end to end without an exception

**Verification:**
- [ ] `flutter analyze` → `No issues found!`
- [ ] `flutter test`
- [ ] `flutter run -d chrome`, walk login → home → new transfer → pick bank → pick account → nominal → confirm → receipt
- [ ] Resize the Chrome window to 320px wide — no yellow/black overflow stripes

**Dependencies:** 1 · **Files:** `add_transaction_screen.dart`, `authentication_screen.dart`, `home_screen.dart`, `status_transaction_screen.dart`, `splash_screen.dart`, `components.dart`, `formatted.dart`, `repository.dart`, `test/widget_test.dart` · **Scope:** L

### ✅ Checkpoint A — Clean baseline
- [ ] `flutter analyze` → 0 issues · `flutter test` → pass · web + Windows builds succeed
- [ ] Every existing screen reachable, transfer flow completes
- [ ] **Review with user before starting the redesign**

---

## Phase 1 — Design system

### Task 3: Material 3 theme, tokens and dark mode

**Description:** Turn the flat palette into a real design system: seed-based `ColorScheme.fromSeed` for light and dark, a `TextTheme` built from the existing Inter scale, and shared tokens for spacing, radii, elevation, glass blur and motion durations/curves. Wire `theme`, `darkTheme` and `themeMode` into `MaterialApp` with a persisted user preference.

**Acceptance criteria:**
- [ ] `ColorScheme` derived from the existing brand blue `#00499B`; both light and dark defined
- [ ] `useMaterial3: true`; component themes for `FilledButton`, `TextField`/`InputDecoration`, `Card`, `TabBar`, `Dialog`, `BottomSheet`
- [ ] Existing `headline1`…`metadata` names still resolve (aliases) so screens migrate incrementally
- [ ] Theme mode (system/light/dark) persists across restart
- [ ] No hardcoded `Color(0x…)` left in any presentation file

**Verification:**
- [ ] `flutter run -d chrome`, toggle dark mode — every screen readable, no white-on-white or black-on-black
- [ ] `flutter analyze` still 0 issues

**Dependencies:** 1 · **Files:** `lib/styles/pallet.dart`, `lib/styles/typography.dart`, new `lib/core/theme/{app_theme,tokens,motion}.dart`, `lib/main.dart` · **Scope:** M

### Task 4: Rebuild the shared UI kit

**Description:** Replace the untyped, `dynamic`-heavy helpers in `components.dart` with typed, themed, accessible widgets — the vocabulary every re-skinned screen will use. Includes the glass card, the animated primary button, the shimmer set redone against theme colors, and one motion helper (staggered fade-slide) used app-wide.

**Acceptance criteria:**
- [ ] `AppButton`, `AppTextField`, `GlassCard`, `AppDialog`, `AppBottomSheet`, `SectionHeader` — all strongly typed, no bare `dynamic` parameters
- [ ] Every interactive element has a ≥48×48 tap target and a `Semantics` label
- [ ] Buttons show pressed/disabled/loading states; primary button animates its press
- [ ] `shimmer.dart` rebuilt against `ColorScheme` so skeletons work in dark mode
- [ ] Reusable `staggeredReveal()` helper wrapping `flutter_animate`

**Verification:**
- [ ] `flutter analyze` → 0 issues
- [ ] `flutter test` passes (add widget tests for `AppButton` disabled state and `AppTextField` error state)
- [ ] Screen-reader labels visible in Flutter DevTools' semantics tree

**Dependencies:** 3 · **Files:** `lib/presentation/widget/components.dart` (split into `lib/presentation/widget/`), `lib/presentation/widget/shimmer.dart` · **Scope:** M

---

## Phase 2 — Re-skin, one screen at a time

Each task below is a complete, independently reviewable visual slice: it converts one screen to the new theme + UI kit, adds its motion, and is verified by running the app.

### Task 5: Splash + onboarding + auth
Animated logo reveal replacing the static 3-second `Image.asset` wait; onboarding page with parallax; auth form with M3 fields, inline validation feedback as you type, password-strength meter, and a page indicator that animates. Fixes the `Visibility(viewInsets.bottom == 0)` keyboard jank with a proper scroll-aware layout.
**Verify:** `flutter run -d chrome` → splash → onboarding → sign up → log in, in both themes, with the keyboard open.
**Dependencies:** 4 · **Files:** `splash_screen.dart`, `authentication_screen.dart` · **Scope:** M

### Task 6: Home
Glass balance cards with a page-indicator carousel and a hero transition into detail; live greeting; animated balance counter; staggered reveal of favorites and recent activity; pull-to-refresh; a real empty state instead of a "Coming Soon" Lottie on tabs that now have content.
**Verify:** run, scroll, switch tabs, toggle theme, resize to 320px.
**Dependencies:** 4 · **Files:** `home_screen.dart` · **Scope:** M

### Task 7: Transfer flow
Re-skinned two-step transfer: searchable bank/account sheets with debounced filtering and result highlighting, formatted currency input, live "remaining balance after transfer" readout, and a confirmation sheet that summarises everything before committing.
**Verify:** run the full transfer path in both themes; search with no match; enter over-balance amounts.
**Dependencies:** 4, 2 · **Files:** `add_transaction_screen.dart`, `transaction_screen.dart` · **Scope:** M

### Task 8: Receipt screen
Success animation, receipt card with real values (no hardcoded name/ref/fee), expandable detail, and correctly wired "Save as Favorite" / "Done" actions that return to the *logged-in* user's home.
**Verify:** complete a transfer, land on receipt, both actions behave.
**Dependencies:** 4, 2 · **Files:** `status_transaction_screen.dart` · **Scope:** S

### ✅ Checkpoint B — Redesign complete
- [ ] Every screen on the M3 theme, light + dark, no legacy palette references
- [ ] `flutter analyze` 0 · `flutter test` pass · web + Windows build
- [ ] Screenshots of each screen in both themes sent to the user
- [ ] **Review with user before starting features**

---

## Phase 3 — Make it real

### Task 9: Local store and money model

**Description:** The foundation for every remaining feature. A `LocalStore` over `shared_preferences` (JSON documents, versioned with a migration hook), a `Money` value type in `int` rupiah with `formatRupiah()`, and `AccountStore` / `TransactionStore` / `SessionStore` `ChangeNotifier`s wired through `provider`. Bundled JSON assets seed the store on first launch; the store is authoritative afterwards. `balance.json` and `transaction.json` migrate from `"5,000,000 "` strings to numbers.

**Acceptance criteria:**
- [ ] Balances and amounts are `int` everywhere; no currency arithmetic on strings
- [ ] First launch seeds from assets; second launch reads the store
- [ ] A store version key exists with a migration path
- [ ] `Repository` is constructed once and injected, not `Repository()` inside `build`

**Verification:**
- [ ] Unit tests for `Money` formatting/parsing and for `LocalStore` seed → read → write → re-read
- [ ] `flutter test` passes
- [ ] Run on Chrome, hot restart — data survives

**Dependencies:** 1 · **Files:** new `lib/data/local/`, `lib/state/`, `lib/data/model/*.dart`, `lib/data/repository/repository.dart`, `lib/assets/json/{balance,transaction}.json` · **Scope:** M

### Task 10: Real accounts and persistent session

**Description:** Sign-up creates a stored user (password hashed, never stored plain — the current `user.json` keeps plaintext passwords); login validates against the store; the session persists so a returning user skips straight to Home; add logout and a profile screen.

**Acceptance criteria:**
- [ ] Signing up then killing and reopening the app lets that new user log in
- [ ] A logged-in user reopening the app lands on Home, not the auth screen
- [ ] Logout clears the session and returns to auth
- [ ] Passwords stored as a salted hash

**Verification:**
- [ ] Unit tests: signup → login → wrong password rejected → logout
- [ ] Manual: sign up, hard-refresh Chrome, land on Home; log out, land on auth

**Dependencies:** 9 · **Files:** `authentication_screen.dart`, `lib/state/session_store.dart`, new profile screen, `main.dart` · **Scope:** M

### Task 11: Transfers that actually move money

**Description:** Committing a transfer debits the source account (plus the admin fee), writes a transaction record with a generated reference, and updates Home's balance and Recent Activity live. Insufficient balance blocks the transfer with a clear message. Adds a real transaction history screen with search — replacing the inert search field on `transaction_screen.dart`.

**Acceptance criteria:**
- [ ] Balance decreases by amount + fee; the arithmetic is exact
- [ ] Transfer is rejected when amount + fee exceeds balance
- [ ] The transaction appears in history immediately and survives restart
- [ ] History search filters by recipient, bank and amount

**Verification:**
- [ ] Unit tests: successful debit, insufficient-funds rejection, fee arithmetic
- [ ] Manual: note the balance, transfer, confirm the new balance and the history entry, restart, confirm both persisted

**Dependencies:** 9, 7 · **Files:** `lib/state/{account,transaction}_store.dart`, `add_transaction_screen.dart`, `status_transaction_screen.dart`, `transaction_screen.dart`, `home_screen.dart` · **Scope:** L

### ✅ Checkpoint C — Money is real
- [ ] Sign up → log in → transfer → balance drops → restart → everything persisted
- [ ] `flutter analyze` 0 · `flutter test` pass
- [ ] **Review with user**

---

## Phase 4 — The useful features

### Task 12: Tracker tab — spending analytics

**Description:** Replace the "Coming Soon" Lottie on the Tracker tab with real analytics over stored transactions: monthly income/spend bar chart, spend-by-category donut, a month-over-month delta, and a monthly budget limit with a warning state when it is approached or exceeded.

**Acceptance criteria:**
- [ ] Charts render from real stored transactions, not sample data
- [ ] Categories auto-assigned from recipient with a manual override
- [ ] Budget limit is settable and persists; exceeding it shows a clear warning
- [ ] A genuine empty state when there are no transactions yet
- [ ] Charts legible in both light and dark themes

**Verification:**
- [ ] Unit tests for the aggregation (per-month totals, per-category totals, budget threshold)
- [ ] Manual: make three transfers, confirm the chart and totals match

**Dependencies:** 11 · **Files:** new `lib/presentation/screen/main/tracker_tab.dart`, `lib/data/analytics/`, `home_screen.dart` · **Scope:** M

### Task 13: Favorites and scheduled transfers

**Description:** Make "Save as Favorite" real (favorites appear as one-tap chips on Home and prefill the transfer form), and fill the empty Autodebit tab with scheduled transfers — weekly/monthly recurrence, evaluated and applied on app open, with a "next due" display and pause/delete.

**Acceptance criteria:**
- [ ] Saving a favorite persists it; tapping it prefills recipient, bank and amount
- [ ] A schedule can be created, paused, resumed and deleted
- [ ] A schedule whose due date has passed executes once on next app open and advances its next-due date
- [ ] A due schedule with insufficient funds fails visibly rather than silently

**Verification:**
- [ ] Unit tests for the due-date engine, including a backdated schedule and the insufficient-funds path
- [ ] Manual: save a favorite, use it; create a schedule, backdate it, restart, confirm it ran once

**Dependencies:** 11 · **Files:** new `lib/data/model/scheduled_transfer.dart`, `lib/state/schedule_store.dart`, `transaction_screen.dart`, `status_transaction_screen.dart`, `home_screen.dart` · **Scope:** L

### Task 14: Receipt export (PDF + image)

**Description:** Turn any receipt or history entry into a shareable artifact — a `RepaintBoundary` PNG and a `pdf`/`printing` PDF, both share-able and save-able on web, Windows and Android.

**Acceptance criteria:**
- [ ] Receipt exports as PDF with amount, recipient, bank, reference, timestamp, fee, total
- [ ] Receipt exports as PNG
- [ ] Export works on Chrome and Windows
- [ ] History entries can be re-exported later

**Verification:**
- [ ] Manual on Chrome: export PDF, open it, check every field
- [ ] Manual on Windows: same

**Dependencies:** 11 · **Files:** new `lib/data/export/receipt_export.dart`, `status_transaction_screen.dart`, history screen · **Scope:** M

### Task 15: QR pay

**Description:** Make the dead QRIS button work. Generate a payment QR encoding a QRIS-style payload (account, name, optional amount) with `qr_flutter`, and accept a payload by paste or manual entry to prefill a transfer. Camera scanning is attempted last via `mobile_scanner`, gated to Android/iOS/web — **if it breaks the Windows build it is dropped**, and the paste path remains.

**Acceptance criteria:**
- [ ] "My QR" renders a scannable code for the selected account
- [ ] A pasted QR payload prefills and validates the transfer form
- [ ] A malformed payload is rejected with a clear error
- [ ] Windows and web builds still succeed

**Verification:**
- [ ] Unit tests for payload encode/decode round-trip and malformed-input rejection
- [ ] Manual: generate on one account, decode into a transfer to another
- [ ] `flutter build windows --debug` and `flutter build web --release` both succeed

**Dependencies:** 11 · **Files:** new `lib/presentation/screen/qr/`, `lib/data/qr/qris_payload.dart`, `home_screen.dart` · **Scope:** M

### ✅ Checkpoint D — Features complete
- [ ] All four feature groups working and persisted
- [ ] `flutter analyze` 0 · `flutter test` pass · both builds succeed
- [ ] **Review with user**

---

## Phase 5 — Ship

### Task 16: Final polish, tests and docs

**Description:** Close the gaps: accessibility pass (contrast, semantics, focus order, text scaling to 200%), empty/error/loading states everywhere, a `README.md` (the repo has none) with screenshots and setup, and refreshed launcher icons.

**Acceptance criteria:**
- [ ] Every async surface has explicit loading, empty and error states
- [ ] App usable at 200% text scale with no overflow
- [ ] Contrast meets WCAG AA in both themes
- [ ] `README.md` documents setup, architecture and features
- [ ] Widget tests cover each main screen; unit tests cover money, analytics, scheduling and QR payloads

**Verification:**
- [ ] `flutter analyze` → 0 · `flutter test` → all pass
- [ ] `flutter build web --release` and `flutter build windows --release` succeed
- [ ] Manual pass through every screen at 200% text scale in both themes

**Dependencies:** 12, 13, 14, 15 · **Files:** `README.md`, `test/`, screens · **Scope:** M

### ✅ Checkpoint E — Done
- [ ] All acceptance criteria met across all tasks
- [ ] **Working tree left clean but uncommitted — the user commits and pushes themselves**

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| `google_fonts` 6→8 and `lottie` 2→3 have breaking API changes | Med | Task 1 is isolated and verified by a full build before any other work starts; roll back individual bumps if a fix is not cheap |
| `flutter_lints` 6 surfaces a large new lint backlog | Med | Absorbed inside Task 2, whose exit bar is already "0 issues" |
| `mobile_scanner` breaks the Windows build | Low | Task 15 is last, camera scan is explicitly droppable, paste path is the primary implementation |
| Migrating balances from `String` to `int` touches many files at once | Med | Task 9 lands the model and its unit tests before Task 11 consumes it; JSON assets migrate in the same commit as the model |
| Scope: 16 tasks is a lot of ground | Med | Five checkpoints with explicit user review; each phase leaves the app fully working, so stopping early still ships something coherent |
| Redesign diverges from what the user pictured | Med | Checkpoint B sends screenshots of every screen in both themes before any feature work begins |

## Open Questions

- **Recipient identity.** The transfer form collects a bank and an account number but never a recipient *name* — which is why `'Rafeh Qazi'` is hardcoded in two places. Plan is to add a recipient-name field in Task 7. Flagging it because it changes the transfer form's shape.
- **Sample data language.** Seed data is Indonesian (Rupiah, Indonesian banks, `id_ID` date formatting) while the UI copy is English. Plan keeps that as-is; say the word if you want the UI localized to Indonesian too.

## How to verify the whole thing

```bash
cd C:/Users/ASUS/projects/Banking_app && flutter analyze && flutter test && flutter run -d chrome
```

End-to-end path: splash → onboarding → **sign up a new user** → log in → Home (balance cards, both themes) → new transfer (pick bank, pick account, enter amount) → confirm → receipt → export PDF → save as favorite → back to Home (**balance decreased**) → Tracker tab (chart reflects the transfer) → create a scheduled transfer → hard-refresh (**everything persisted**) → log out → log back in.
