# Newtronic Banking

A Flutter banking app: real balances, real transfers, spending analytics,
scheduled payments, QR payment codes and exportable receipts — all persisted
locally, running on web, Windows, Android, iOS, macOS and Linux.

Around 12,000 lines of Dart across 75 files, with 343 tests.

---

## Running it

```bash
flutter pub get
flutter run -d chrome
```

Windows, or any other target:

```bash
flutter run -d windows
```

Requires Flutter 3.47 or newer (Dart 3.13). No keys, no accounts, no backend to
stand up — the app seeds itself from bundled JSON on first launch.

### Signing in

There are seeded users, or sign up for a new one. A new account survives a
restart: sign up, close the app, and log back in with the same details.

---

## What it does

**Accounts.** Balances are whole rupiah held as integers, never strings. The
home carousel shows each account; tapping one opens its detail with a Hero
transition.

**Transfers that move money.** Committing a transfer debits the source account
plus the admin fee, writes a transaction with a generated reference, and
updates the balance everywhere at once. Insufficient funds block the transfer
rather than driving the balance negative. If recording the transaction fails
after the debit, the debit is rolled back.

**History and search.** Every transfer is searchable by payee, bank, note,
reference, account number, or amount — typed either grouped (`250.000`) or as
plain digits.

**Tracker.** Spending by category over real stored transactions: a composition
bar, a ranked list, a month-over-month delta, and a monthly budget with a
warning state. Categories are guessed from the payee and can be overridden.

**Favourites and schedules.** Save a recipient and reuse them in one tap.
Schedule a transfer weekly or monthly; due schedules run when the app opens and
report what they did.

**QR pay.** Generate a payment code for one of your accounts — open, or with
the amount fixed — and share it as an image. Read a code by pasting it: the app
shows exactly what it decoded before anything is sent.

**Receipts.** Any transfer exports as a PDF (composed as text, so it stays
selectable and searchable) or as a PNG of the on-screen card. Past transfers
can be re-opened from history and exported again.

**Light and dark.** Both themes are designed, not flipped. The choice persists.

---

## Architecture

```
lib/
  core/theme/     design tokens, the two themes, the motion language
  data/
    analytics/    spending categories and aggregation
    export/       receipt PDF, widget-to-PNG capture
    local/        the store over shared_preferences, versioned
    model/        Money, accounts, transactions, receipts, schedules
    qr/           the EMVCo payment-code codec
    repository/   seeding and reads
    security/     PBKDF2 password hashing
    utils/        formatting, input formatters, password strength
  presentation/
    screen/       one folder per area
    widget/       the shared UI kit, behind one barrel import
  state/          ChangeNotifier stores, wired through provider
```

### The decisions worth knowing

**`shared_preferences` and JSON, not `sqflite`.** `sqflite` has no web or
Windows support without extra packages, and both are targets here. The data
volumes are tiny. The store is versioned with a migration hook.

**Seed, then own.** Bundled JSON seeds the store on first launch; after that
the store is authoritative. Keeps the sample data without making it read-only.

**Money is an `int` of whole rupiah.** Rupiah has no minor unit in practice.
Amounts were strings (`"5,000,000 "`, trailing space included), which made
arithmetic impossible — that is why nothing used to debit.

**`provider` with `ChangeNotifier`.** Every screen used to build a fresh
`Repository` inside `build`, re-reading and re-decoding JSON on each frame. A
handful of stores give one source of truth and live updates, without the weight
of a larger state library.

**Passwords are hashed with PBKDF2-HMAC-SHA256, and that is not a security
boundary.** It keeps a readable password out of local storage. Anything running
on the device can still call the same code. Real protection needs a server that
never ships the hash to the client. The iteration count is a deliberate
compromise for the web build's UI isolate.

**Payment codes are real EMVCo tag-length-value** — the shape QRIS uses,
CRC-16 trailer included — rather than a private format. Fields are sliced as
bytes because EMVCo lengths count bytes, so a non-Latin payee name does not
shift every field after it.

**Scheduled transfers run on app open, not in the background.** Background
scheduling is impossible on web and needs a notification package with no web
support elsewhere. A schedule left unopened for months catches up to the
present in one step rather than firing every missed occurrence, which would
empty an account without warning.

---

## Tests

```bash
flutter analyze
flutter test
```

343 tests. Beyond the per-screen widget tests, three suites are worth calling
out because they check things that are easy to get wrong by eye:

- **`contrast_test.dart`** measures every foreground/background pair in both
  themes against WCAG AA and fails below it. It found four real failures,
  including brand text at 1.94:1.
- **`text_scale_test.dart`** pumps every screen at 200% text on a 360px phone
  and fails on any overflow, since Flutter reports overflow as an exception.
- **`qris_payload_test.dart`** covers the codec's rejection paths: a damaged
  checksum, a wrong currency, an account number of the wrong length, and a
  second amount appended after the first.

### Known gaps

- **No visual review has been done.** The screens have not been looked at by a
  person in this environment; the layout checks above are automated only.
- **Sharing is not covered by a test.** Export opens the platform share sheet,
  which a widget test cannot drive. The document's contents, the PNG capture
  and the offline font fallback are covered; the dialog appearing is not.
- **No camera scanning.** `mobile_scanner` has no Windows support. Codes are
  read by pasting them, which is also the fallback a camera would need for a
  code that is scratched or badly lit.

---

## Platforms

Verified on **Chrome** and **Windows**. Android, iOS, macOS and Linux build
from the same source with no platform-specific code, but have not been run.
