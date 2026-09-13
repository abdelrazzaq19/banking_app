import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newtronic_banking/core/theme/app_theme.dart';
import 'package:newtronic_banking/core/theme/theme_controller.dart';
import 'package:newtronic_banking/data/local/local_store.dart';
import 'package:newtronic_banking/data/repository/repository.dart';
import 'package:newtronic_banking/state/account_store.dart';
import 'package:newtronic_banking/state/favourite_store.dart';
import 'package:newtronic_banking/state/schedule_store.dart';
import 'package:newtronic_banking/state/session_store.dart';
import 'package:newtronic_banking/state/spending_store.dart';
import 'package:newtronic_banking/state/transaction_store.dart';
import 'package:newtronic_banking/state/transfer_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The data layer a screen needs, built over an empty in-memory store.
class TestBackend {
  TestBackend({
    required this.store,
    required this.repository,
    required this.accounts,
    required this.transactions,
    required this.session,
    required this.transfers,
    required this.spending,
    required this.favourites,
    required this.schedules,
  });

  final LocalStore store;
  final Repository repository;
  final AccountStore accounts;
  final TransactionStore transactions;
  final SessionStore session;
  final TransferService transfers;
  final SpendingStore spending;
  final FavouriteStore favourites;
  final ScheduleStore schedules;
}

/// Builds a fresh store, seeds it from the bundled JSON, and loads the stores.
///
/// Each call starts from empty `shared_preferences`, so tests cannot leak state
/// into one another through the singleton the app uses at runtime.
Future<TestBackend> createTestBackend() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  // `rootBundle` memoizes the Future, not just the string, and that Future
  // resolved inside a previous test's FakeAsync zone. Re-reading an asset
  // without clearing would attach to that dead zone and never complete.
  rootBundle.clear();

  final store = await LocalStore.open();
  final repository = Repository(store: store);
  await repository.ensureSeeded();

  final accounts = AccountStore(repository);
  final transactions = TransactionStore(repository);
  final session = SessionStore(repository: repository, store: store);
  final spending = SpendingStore(store);
  await spending.load();
  final favourites = FavouriteStore(store);
  await favourites.load();
  final schedules = ScheduleStore(store);
  await schedules.load();
  await accounts.load();
  await transactions.load();
  await session.restore();

  return TestBackend(
    store: store,
    repository: repository,
    accounts: accounts,
    transactions: transactions,
    session: session,
    transfers: TransferService(
      accounts: accounts,
      transactions: transactions,
    ),
    spending: spending,
    favourites: favourites,
    schedules: schedules,
  );
}

/// Wraps [child] in the providers and theme the real app supplies.
Widget wrapWithBackend(
  TestBackend backend, {
  Widget? child,
  RouteFactory? onGenerateRoute,
  String? initialRoute,
  ThemeMode themeMode = ThemeMode.light,
  ThemeController? themeController,
}) {
  assert(
    child != null || onGenerateRoute != null,
    'supply either a home widget or a route factory',
  );

  return MultiProvider(
    providers: [
      Provider<LocalStore>.value(value: backend.store),
      Provider<Repository>.value(value: backend.repository),
      ChangeNotifierProvider<AccountStore>.value(value: backend.accounts),
      ChangeNotifierProvider<TransactionStore>.value(
        value: backend.transactions,
      ),
      ChangeNotifierProvider<SessionStore>.value(value: backend.session),
      Provider<TransferService>.value(value: backend.transfers),
      ChangeNotifierProvider<SpendingStore>.value(value: backend.spending),
      ChangeNotifierProvider<FavouriteStore>.value(value: backend.favourites),
      ChangeNotifierProvider<ScheduleStore>.value(value: backend.schedules),
      // Nullable on purpose: the app itself supplies null until the stored
      // preference has loaded, and the screens that read it handle that.
      ChangeNotifierProvider<ThemeController?>.value(value: themeController),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: child,
      // Only meaningful with a route factory; MaterialApp asserts if both a
      // home and an initialRoute are given.
      initialRoute: child == null ? initialRoute : null,
      onGenerateRoute: onGenerateRoute,
    ),
  );
}

/// Rebuilds a [SpendingStore] over the same store, as a relaunch would, so a
/// test can check that a setting was actually written rather than only held.
Future<SpendingStore> createReloadedSpendingStore(TestBackend backend) async {
  final reloaded = SpendingStore(backend.store);
  await reloaded.load();
  return reloaded;
}

/// Gives the tester a phone-shaped surface for the duration of a test.
void useMobileSurface(
  WidgetTester tester, {
  Size size = const Size(430, 1100),
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Pumps until [finder] matches, or gives up after [maxFrames].
///
/// `pumpAndSettle` is unusable on screens holding network-image placeholders or
/// looping Lottie animations — neither ever settles.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 60,
}) async {
  for (var frame = 0; frame < maxFrames; frame++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Wraps [child] so it lays out at [scale] times the normal text size.
///
/// Overflow is reported by the framework as an exception during paint, so a
/// test that pumps a screen at 200% and finds `tester.takeException()` null
/// has actually checked the layout, not just that it built.
Widget atTextScale(double scale, Widget child) => Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
        ),
        child: child,
      ),
    );

/// Rebuilds a [SessionStore] over the same store, as a relaunch would.
///
/// Proves a change was written rather than only held in memory.
Future<SessionStore> createReloadedSession(TestBackend backend) async {
  final reloaded = SessionStore(
    repository: backend.repository,
    store: backend.store,
  );
  await reloaded.restore();
  return reloaded;
}
