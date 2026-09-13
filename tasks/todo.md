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
  - [x] MOVE/QRIS card-action colour now comes from `AppButtonVariant.onCard`,
        asserted by a contrast test and by a home test checking the variant.
        Still never seen rendered — the preview surfaces in this environment
        cannot show Flutter's canvas reliably.

- [x] **Task 4 — Shared UI kit** (M) — depends on 3
  - [x] `AppButton`, `AppTextField`, `GlassCard`, `AppDialog`, `AppBottomSheet`, `SectionHeader` — typed, no bare `dynamic`
  - [x] ≥48×48 tap targets and `Semantics` labels throughout
  - [x] Pressed / disabled / loading button states
  - [x] Shimmer skeletons rebuilt against `ColorScheme` (work in dark mode)
  - [x] `staggeredReveal()` motion helper
  - [x] Widget tests for button disabled state and field error state
  - [x] Old dialog helpers removed rather than duplicated: `app_dialog.dart`
        would have collided with the same names in `components.dart`, so the
        three call sites moved to the awaitable `showConfirmDialog`
  - [x] 22 UI-kit tests; suite now 56 passing, both platform builds green
  - [x] Old dialog helpers removed rather than duplicated: `app_dialog.dart`
        would have collided with the same names in `components.dart`, so the
        three call sites moved to the awaitable `showConfirmDialog`
  - [x] 22 UI-kit tests; suite now 56 passing, both platform builds green

---

## Phase 2 — Re-skin, screen by screen

- [x] **Task 5 — Splash + onboarding + auth** (M) — depends on 4
  - [x] Animated logo reveal replaces the static 3-second wait
  - [x] Inline validation feedback and a password-strength meter
  - [x] Keyboard no longer causes layout jank
- [x] **Task 6 — Home** (M) — depends on 4
  - [x] Glass balance-card carousel with hero transition to detail
  - [x] Animated balance counter, staggered list reveals, pull-to-refresh
- [x] **Task 7 — Transfer flow** (M) — depends on 4, 2
  - [x] Debounced searchable bank/account sheets
  - [x] Formatted currency input and live remaining-balance readout
  - [x] Confirmation sheet summarising the transfer
  - [x] Insufficient-funds block brought forward from Task 11: the readout
        would otherwise show a red negative balance beside a live button
  - [x] Recipient-name field added (see Open Questions in plan.md)
- [x] **Task 8 — Receipt screen** (S) — depends on 4, 2
  - [x] Real values throughout, expandable detail, correctly wired actions
  - [x] `ReceiptCard` extracted as its own widget so Task 14 can render the
        same layout for the PNG/PDF export
  - [x] Success animation plays once and holds instead of looping
  - [x] "Save as Favorite" no longer claims a save it cannot make: it
        acknowledges, disables itself, and stays on the receipt until
        Task 13 gives favourites somewhere to live

- [~] **✅ Checkpoint B — Redesign complete.**
  - [x] Every screen on the M3 theme, no legacy palette references left
  - [x] `flutter analyze` clean, 106 tests passing, web + Windows builds green
  - [ ] **Screenshots not produced.** The in-app browser pane mis-renders
        Flutter's canvas (clipping, offset and tiling artifacts across three
        sessions) and off-screen capture of the Windows build returns black,
        because a background process cannot take foreground focus. Visual
        review needs `flutter run -d chrome` on the user's own machine.
  - [ ] Review with user before feature work

---

## Phase 3 — Make it real

- [x] **Task 9 — Local store and money model** (M) — depends on 1
  - [x] `LocalStore` over `shared_preferences`, versioned with a migration hook
  - [x] `Money` as `int` rupiah plus `formatRupiah()`; JSON seed data migrated off strings
  - [x] `SessionStore` / `AccountStore` / `TransactionStore` wired through `provider`
  - [x] `Repository` injected once, never constructed inside `build`
  - [x] Unit tests for money formatting and store seed/read/write round-trip
  - [x] Seed-then-own proven: a spent balance survives a simulated relaunch
  - [x] Corrupt stored JSON degrades to empty instead of crashing at launch
  - [x] `test/support/test_harness.dart` builds a real store per test, so
        tests cannot leak state through the app's singleton

- [x] **Task 10 — Real accounts and persistent session** (M) — depends on 9
  - [x] Sign-up creates a stored user with a salted password hash
  - [x] Login validates against the store; wrong password rejected
  - [x] Returning user lands on Home; logout returns to auth
  - [x] Profile screen, with a System/Light/Dark selector and sign-out
  - [x] PBKDF2-HMAC-SHA256 with per-password salt and constant-time compare
  - [x] Seeded plaintext passwords hashed on first read; plaintext never
        reaches the store
  - [~] **Scope note:** hashing keeps a readable password out of the local
        store, but a local store is not a security boundary — anything on
        the device can call the hasher. Iterations are deliberately modest
        (10k) because this runs on the UI isolate on web. Both documented
        on `PasswordHasher`.

- [x] **Task 11 — Transfers that move money** (L) — depends on 9, 7
  - [x] Source account debited by amount + fee, arithmetic exact
  - [x] Insufficient balance blocks the transfer with a clear message
  - [x] Transaction written, appears in history immediately, survives restart
  - [x] History screen with working search (replaces the inert search field)
  - [x] `TransferService` rolls the debit back if the record cannot be written
  - [x] The `Accounts` tab — an empty state pretending to be content — is now
        a real `History` tab backed by the store
  - [x] Home watches the stores, so a balance change shows without a reload,
        and pull-to-refresh is finally meaningful

- [x] **✅ Checkpoint C — Money is real.**
  - [x] `flutter analyze` clean, 189 tests passing, web + Windows builds green
  - [x] The journey is covered end to end by `test/checkpoint_c_test.dart`:
        sign up, transfer, balance drops, relaunch, session and money both
        persist, sign out, sign back in
  - [ ] Visual review still outstanding (see Checkpoint B)

---

## Phase 4 — Features

- [x] **Task 12 — Tracker analytics** (M) — depends on 11
  - [x] Monthly bar chart from real transactions
  - [~] **Donut replaced by a composition bar + ranked list.** The dataviz
        guidance is explicit that a donut is wrong for comparing close
        values; the ranked list compares properly and doubles as the
        recategorise surface. Budget is a meter, not a two-slice pie.
  - [x] Auto-assigned categories with manual override
  - [x] Persisted budget limit with a warning state
  - [x] Real empty state; charts legible in both themes
  - [x] Unit tests for the aggregation
  - [x] Categorical palette validated with the dataviz checker against
        this app's own surfaces, both modes; light mode's three
        sub-3:1 slots carry the required label relief

- [ ] **Task 13 — Favorites and scheduled transfers** (L) — depends on 11
  - [ ] Favorites persist and prefill the transfer form
  - [ ] Schedules can be created, paused, resumed, deleted
  - [ ] A due schedule executes once on app open and advances its next-due date
  - [ ] Insufficient funds on a due schedule fails visibly
  - [ ] Unit tests for the due-date engine

- [x] **Task 14 — Receipt export** (M) — depends on 11
  - [x] PDF export carrying every field, composed as text so it stays
        selectable and searchable rather than being a picture of a screen
  - [x] PNG export rasterises the on-screen card through a `RepaintBoundary`,
        so the image cannot drift from what was looked at
  - [x] History entries re-exportable: `ReceiptDetailScreen` rebuilds a stored
        transfer into a receipt; a seeded entry that was never a transfer
        correctly offers nothing to export
  - [x] Web and Windows builds green with `share_plus` added (`printing`
        shares PDFs only, so the image needed its own route)
  - [x] Unicode names survive the PDF. The pdf package's built-in Helvetica is
        Latin-1 only, so an accented recipient name would have been written to
        the receipt wrong; Inter is loaded instead, falling back to Helvetica
        if the download fails so an offline export still produces a document
  - [x] `RemoteImage` replaces eight hand-rolled `CachedNetworkImage` blocks.
        Every one passed a possibly-empty URL, which `CachedNetworkImage`
        treats as a URL to fetch — opening its cache manager and asking
        `path_provider` for a directory for a request that cannot succeed.
        Logo-less banks and payees are the common case, not the rare one.
  - [ ] **Not verified by hand on Chrome or Windows.** The export opens the
        platform share sheet, which this environment cannot drive; the tests
        cover the document's contents, the capture and the fallback, but not
        that the share dialog appears.

  Notes on how the tests ended up shaped the way they are:
  - PDF content is asserted through `documentRows` / `amountRows` rather than
    by searching the saved bytes. The writer splits strings across kerned `TJ`
    runs, so `Siti Rahayu` can be written `[(Siti) -20 (Rahayu)]` and never
    match as a substring — an earlier version of these tests searched the
    bytes and passed only because it was asserting almost nothing.
  - `capturePng` must be driven inside `tester.runAsync`: the image future is
    completed by the engine, not the test's fake clock, so awaiting it on the
    fake clock hangs. It did — for 9m22s, stalling every later test in the
    file.
  - `ExportOutcome` was written and never called by anything; removed rather
    than left as a second, unused way to report the same failures.

- [x] **Task 15 — QR pay** (M) — depends on 11
  - [x] "My QR" generates a scannable code for a chosen account, either open
        ("pay me") or with the amount fixed ("pay me this"), shareable as an
        image
  - [x] A pasted code is decoded, shown in full, and only then hands the
        details to the transfer form — nothing is sent from this screen
  - [x] Malformed codes are refused with the specific reason: damaged
        checksum, wrong currency, no payee named, an account number of the
        wrong length, an amount that is not whole rupiah, or not a payment
        code at all
  - [x] Both QRIS buttons wired — the home balance card and the account detail
        screen, each opening a sheet that forks between showing and reading
  - [x] Web and Windows builds green
  - [ ] **Camera scanning dropped, as the plan allowed.** `mobile_scanner` has
        no Windows support and Windows is one of the two verification targets,
        so it would have been a button that cannot be built for half the
        platforms it ships to. Paste covers the case that actually happens on
        desktop and web — a code arriving in a chat message — and it is the
        fallback a camera needs anyway for a code that is scratched or badly
        lit.

  Decisions worth recording:
  - The payload is real EMVCo tag-length-value with a CRC-16/CCITT-FALSE
    trailer, the shape Indonesian QRIS codes use, rather than a private
    format. That makes the round-trip and rejection tests mean something: a
    single altered character fails the checksum, a second amount appended
    after the first is ignored rather than overriding what the payer was
    shown. Fields are sliced as bytes, not characters, because EMVCo lengths
    count bytes — counting them in Dart's UTF-16 code units would shift every
    field after a non-Latin payee name.
  - The account-number rule widened from a flat 12 digits to 10-16. Real
    Indonesian account numbers vary in that range, and the fixed 12 rejected
    every code generated from one of this app's own 16-digit cards.
  - `TransferPrefill` replaced `FavouriteTransfer` as what the transfer form
    opens with. A scanned code is not a saved favourite; passing one would
    have meant fabricating an id and a created-at for a payee nobody saved.
  - A code naming a bank this app does not carry says so, and leaves the bank
    field empty rather than filling in a near miss.
  - `WidgetCapture` was lifted out of `ReceiptExporter` so the QR screen can
    share an image without importing receipt code.
  - Clipboard reads are now guarded. `Clipboard.getData` throws rather than
    returning null when the platform answers with no text, and a browser can
    refuse the read outright — the paste button had no handler for either.

- [x] **✅ Checkpoint D — Features complete.**
  - [x] All four feature groups working and persisted: real money with a local
        store, Tracker analytics, favourites and scheduled transfers, QR pay
        and receipt export
  - [x] `flutter analyze` clean, 312 tests passing, web and Windows builds
        green
  - [ ] Visual review still outstanding, for the reason recorded at
        Checkpoint B — it needs `flutter run -d chrome` on the user's machine

---

## Phase 5 — Ship

- [x] **Task 16 — Polish, tests, docs** (M) — depends on 12, 13, 14, 15
  - [x] Loading, empty and error states on every async surface
  - [x] Usable at 200% text scale with no overflow, checked by a test rather
        than by eye
  - [x] WCAG AA contrast in both themes, measured by a test
  - [x] `README.md` with setup, architecture, features and the known gaps
  - [x] Widget tests for every screen; unit tests for money, analytics,
        scheduling and QR payloads. 353 tests.
  - [ ] **Screenshots not included in the README**, for the reason recorded at
        Checkpoint B — they need `flutter run -d chrome` on the user's machine.
  - [ ] **Launcher icons not regenerated.** The only square source in the repo
        is `newtronic.png` at 70x70. Generating from it would upscale to
        512x512 and ship blurrier icons than the Flutter defaults already
        there. This needs a source of at least 1024x1024; the config is left
        as it was rather than made worse.

  What the accessibility work actually found — all of it real, none of it
  visible without the tests:

  - **Five screens overflowed at 200% text.** The balance card carried a fixed
    236px carousel height and a fixed 200px detail height, neither of which
    grew with the text; `context.scaledHeight` now scales them, capped so a
    card cannot push everything else off the screen. The history and home
    activity rows put an unconstrained amount-and-date column beside the payee
    name, which ran 101px past the row edge — the column is now flexible, and
    the amount wraps rather than ellipsizing, because half a figure is worse
    than a figure on two lines.
  - **Four contrast failures.** `success` measured 3.51:1 while carrying text,
    `accent` 4.27:1, and two chart series sat under 3:1 on white — yellow at
    2.17:1. The field outline was the divider grey at 1.35:1, which is the
    boundary WCAG asks 3:1 of, so `outline` became a real border tone and
    input decoration was pointed at it; `mutedBorder` stays light for dividers,
    which are decorative and exempt.
  - Darkening the aqua chart series to clear 3:1 dropped it to 5.5 deltaE from
    the orange under protanopia. Moving it round to teal restored 11.1 while
    keeping enough chroma not to read as grey. Both palettes were re-run
    through the palette validator and pass every check.

  Three more controls that did nothing, found while auditing the states:

  - The **transfer form's Favorites tab** was a fixed "No favourites yet" panel
    that said the same thing whether the user had none or twenty. Favourites
    became real in Task 13 and this second entry point was never connected; it
    now lists them and fills the form in place when one is tapped.
  - **Home's recent activity rows** had `onTap: () {}` — an ink ripple and
    nothing else, which reads as the app having failed to respond. They now
    open the receipt, and rows that never had one are not tappable at all.
  - **"Forgot Password?"** was an empty callback. There is nothing to reset: a
    password here is only ever a hash in this device's storage, with no server
    holding an account and no address to send a link to. It now says that, and
    offers the one thing that does work.

  Also fixed: the transfer form had no handler for a failed bank-list read, so
  a corrupt bundle left the pickers empty with no explanation.

- [x] **✅ Checkpoint E — Done.**
  - [x] `flutter analyze` → No issues found
  - [x] `flutter test` → 353 passing
  - [x] `flutter build web --release` and `flutter build windows --release`
        both succeed
  - [x] Working tree left uncommitted, for the user to commit and push
  - [ ] **Visual review still outstanding.** Carried from Checkpoint B: the
        in-app browser mis-renders Flutter's canvas and an off-screen capture
        of the Windows build comes back black, because a background process
        cannot take foreground focus. Every layout claim above rests on the
        automated overflow and contrast checks, not on anyone having looked at
        the app. `flutter run -d chrome` on your own machine is the missing
        step.
