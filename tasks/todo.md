# Newtronic Banking — Task List

Full detail for every task lives in [plan.md](plan.md). Check items off as they land.

Commits and pushes are the user's job. Leave the working tree clean but uncommitted.

---

## Phase 0 — Clean baseline

- [x] **Task 1 — Toolchain and dependencies** (S)
  - [x] `tasks/plan.md` and `tasks/todo.md` written into the repo
  - [x] Add `provider`, `shared_preferences`, `fl_chart`, `qr_flutter`, `flutter_animate`, `pdf`, `printing`
  - [x] Remove `sqflite`; move `flutter_launcher_icons` to `dev_dependencies`
  - [x] Upgrade `google_fonts` 6→8, `lottie` 2→3, `intl` 0.18→0.20, `cached_network_image` 3→4, `flutter_svg` →2.3, `shimmer` 3→4, `cupertino_icons` →1.0.9, `flutter_lints` 2→6
  - [x] `flutter pub get`, `flutter build web --release`, `flutter build windows --debug` all succeed

- [x] **Task 2 — Fix every known defect** (L) — depends on 1
  - [x] `filteredBanks`/`filteredBalances` assigned after the data loads
  - [x] Account picker search and selection actually work (drop `tempBalance` and its inverted guard)
  - [x] `tempBank[0]` and the two `bankNumberController` `substring` calls made range-safe
  - [x] `formattedBankNumber` no longer throws on digit counts not divisible by 4
  - [x] `mounted` guards on all six async-gap `BuildContext` uses
  - [x] Username rule `< 6 && > 12` corrected to `< 6 || > 12`
  - [x] Password rule rewritten as explicit named checks
  - [x] Login pops the dialog route before navigating; uses `pushReplacementNamed`
  - [x] Hardcoded `arguments: 5`, `'Rafeh Qazi'`, ref number and admin fee removed
  - [x] `customTextField`'s dead `onTapTextField` parameter fixed
  - [x] Dead code deleted (`customDraggableModalBottomSheet` in `components.dart`, `filterAccounts`, `formattedDate`, `searchBankByName`, `getBanksById`)
  - [x] `WillPopScope` → `PopScope` (3), `withOpacity` → `withValues` (25)
  - [x] Home's fixed-height panel made flexible — no overflow at 320px
  - [x] `test/widget_test.dart` replaced with a real smoke test
  - [x] `flutter analyze` → 0 issues, `flutter test` → pass

- [x] **✅ Checkpoint A — Clean baseline.** Analyze clean, tests pass, both builds succeed, transfer flow completes end to end. Review with user.

---

## Phase 1 — Design system

- [x] **Task 3 — Material 3 theme, tokens, dark mode** (M) — depends on 1
  - [x] Light and dark `ColorScheme` seeded from brand blue `#00499B`
  - [x] `useMaterial3: true` plus component themes (button, input, card, tab bar, dialog, bottom sheet)
  - [x] Spacing, radius, elevation, glass-blur and motion tokens
  - [x] Legacy `headline1`…`metadata` names kept as aliases for incremental migration
  - [x] Theme mode persists across restart
  - [x] No hardcoded `Color(0x…)` left in presentation files
  - [x] Contrast fix: white on the light brand blue measured 1.94:1; header and
        card gradients deepened to clear WCAG AA, guarded by 6 contrast tests
  - [ ] **Open:** confirm the MOVE/QRIS card-action colour in a freshly compiled
        dev build — the fix is in source and unit-tested, but the browser was
        still serving a pre-fix bundle when we stopped

- [ ] **Task 4 — Shared UI kit** (M) — depends on 3
  - [ ] `AppButton`, `AppTextField`, `GlassCard`, `AppDialog`, `AppBottomSheet`, `SectionHeader` — typed, no bare `dynamic`
  - [ ] ≥48×48 tap targets and `Semantics` labels throughout
  - [ ] Pressed / disabled / loading button states
  - [ ] Shimmer skeletons rebuilt against `ColorScheme` (work in dark mode)
  - [ ] `staggeredReveal()` motion helper
  - [ ] Widget tests for button disabled state and field error state

---

## Phase 2 — Re-skin, screen by screen

- [ ] **Task 5 — Splash + onboarding + auth** (M) — depends on 4
  - [ ] Animated logo reveal replaces the static 3-second wait
  - [ ] Inline validation feedback and a password-strength meter
  - [ ] Keyboard no longer causes layout jank
- [ ] **Task 6 — Home** (M) — depends on 4
  - [ ] Glass balance-card carousel with hero transition to detail
  - [ ] Animated balance counter, staggered list reveals, pull-to-refresh
- [ ] **Task 7 — Transfer flow** (M) — depends on 4, 2
  - [ ] Debounced searchable bank/account sheets
  - [ ] Formatted currency input and live remaining-balance readout
  - [ ] Confirmation sheet summarising the transfer
  - [ ] Recipient-name field added (see Open Questions in plan.md)
- [ ] **Task 8 — Receipt screen** (S) — depends on 4, 2
  - [ ] Real values throughout, expandable detail, correctly wired actions

- [ ] **✅ Checkpoint B — Redesign complete.** Every screen on the M3 theme in both modes, builds and tests green, screenshots sent to user. Review before feature work.

---

## Phase 3 — Make it real

- [ ] **Task 9 — Local store and money model** (M) — depends on 1
  - [ ] `LocalStore` over `shared_preferences`, versioned with a migration hook
  - [ ] `Money` as `int` rupiah plus `formatRupiah()`; JSON seed data migrated off strings
  - [ ] `SessionStore` / `AccountStore` / `TransactionStore` wired through `provider`
  - [ ] `Repository` injected once, never constructed inside `build`
  - [ ] Unit tests for money formatting and store seed/read/write round-trip

- [ ] **Task 10 — Real accounts and persistent session** (M) — depends on 9
  - [ ] Sign-up creates a stored user with a salted password hash
  - [ ] Login validates against the store; wrong password rejected
  - [ ] Returning user lands on Home; logout returns to auth
  - [ ] Profile screen

- [ ] **Task 11 — Transfers that move money** (L) — depends on 9, 7
  - [ ] Source account debited by amount + fee, arithmetic exact
  - [ ] Insufficient balance blocks the transfer with a clear message
  - [ ] Transaction written, appears in history immediately, survives restart
  - [ ] History screen with working search (replaces the inert search field)

- [ ] **✅ Checkpoint C — Money is real.** Sign up → transfer → balance drops → restart → still there. Review with user.

---

## Phase 4 — Features

- [ ] **Task 12 — Tracker analytics** (M) — depends on 11
  - [ ] Monthly bar chart and spend-by-category donut from real transactions
  - [ ] Auto-assigned categories with manual override
  - [ ] Persisted budget limit with a warning state
  - [ ] Real empty state; charts legible in both themes
  - [ ] Unit tests for the aggregation

- [ ] **Task 13 — Favorites and scheduled transfers** (L) — depends on 11
  - [ ] Favorites persist and prefill the transfer form
  - [ ] Schedules can be created, paused, resumed, deleted
  - [ ] A due schedule executes once on app open and advances its next-due date
  - [ ] Insufficient funds on a due schedule fails visibly
  - [ ] Unit tests for the due-date engine

- [ ] **Task 14 — Receipt export** (M) — depends on 11
  - [ ] PDF export with every field; PNG export
  - [ ] Works on Chrome and Windows; history entries re-exportable

- [ ] **Task 15 — QR pay** (M) — depends on 11
  - [ ] "My QR" generates a scannable payment code
  - [ ] Pasted payload prefills and validates the transfer form
  - [ ] Malformed payload rejected clearly
  - [ ] Windows and web builds still succeed (camera scan dropped if it breaks Windows)

- [ ] **✅ Checkpoint D — Features complete.** All four feature groups working and persisted. Review with user.

---

## Phase 5 — Ship

- [ ] **Task 16 — Polish, tests, docs** (M) — depends on 12, 13, 14, 15
  - [ ] Loading, empty and error states on every async surface
  - [ ] Usable at 200% text scale with no overflow; WCAG AA contrast in both themes
  - [ ] `README.md` with setup, architecture, features and screenshots
  - [ ] Widget tests per screen; unit tests for money, analytics, scheduling, QR

- [ ] **✅ Checkpoint E — Done.** All acceptance criteria met. Working tree left uncommitted for the user to commit and push.
