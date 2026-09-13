import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:newtronic_banking/core/theme/app_theme.dart';
import 'package:newtronic_banking/core/theme/motion.dart';
import 'package:newtronic_banking/core/theme/theme_controller.dart';
import 'package:newtronic_banking/data/local/local_store.dart';
import 'package:newtronic_banking/data/model/transfer_receipt.dart';
import 'package:newtronic_banking/data/repository/repository.dart';
import 'package:newtronic_banking/presentation/screen/auth/authentication_screen.dart';
import 'package:newtronic_banking/presentation/screen/main/home_screen.dart';
import 'package:newtronic_banking/presentation/screen/main/profile_screen.dart';
import 'package:newtronic_banking/presentation/screen/splash_screen.dart';
import 'package:newtronic_banking/presentation/screen/transactions/add_transaction_screen.dart';
import 'package:newtronic_banking/presentation/screen/transactions/transfer_args.dart';
import 'package:newtronic_banking/presentation/screen/transactions/status_transaction_screen.dart';
import 'package:newtronic_banking/presentation/screen/transactions/transaction_screen.dart';
import 'package:newtronic_banking/state/account_store.dart';
import 'package:newtronic_banking/state/favourite_store.dart';
import 'package:newtronic_banking/state/schedule_store.dart';
import 'package:newtronic_banking/state/session_store.dart';
import 'package:newtronic_banking/state/spending_store.dart';
import 'package:newtronic_banking/state/transaction_store.dart';
import 'package:newtronic_banking/state/transfer_service.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Date formatting is used on screens that can render before any screen-level
  // initialisation runs, so the locale data is loaded once up front.
  await initializeDateFormatting('id_ID', null);

  final store = await LocalStore.open();
  final repository = Repository(store: store);
  await repository.ensureSeeded();

  runApp(
    MyApp(
      themeController: await ThemeController.load(),
      store: store,
      repository: repository,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.themeController,
    this.store,
    this.repository,
  });

  /// All three are injected so tests can supply their own; `main` builds them
  /// for the real app.
  final ThemeController? themeController;
  final LocalStore? store;
  final Repository? repository;

  static Route<dynamic> _fadeRoute(Widget page) => PageRouteBuilder(
        pageBuilder: (_, _, _) => page,
        transitionDuration: Motion.medium,
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Motion.enter),
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final controller = themeController;
    final localStore = store;
    final repo = repository;

    // Without the data layer there is nothing to provide — a widget test
    // pumping a single screen supplies its own.
    if (localStore == null || repo == null) {
      return controller == null
          ? const _App()
          : ChangeNotifierProvider<ThemeController>.value(
              value: controller,
              child: const _App(),
            );
    }

    return MultiProvider(
      providers: [
        if (controller != null)
          ChangeNotifierProvider<ThemeController>.value(value: controller),
        Provider<LocalStore>.value(value: localStore),
        Provider<Repository>.value(value: repo),
        ChangeNotifierProvider<SessionStore>(
          create: (_) =>
              SessionStore(repository: repo, store: localStore)..restore(),
        ),
        ChangeNotifierProvider<AccountStore>(
          create: (_) => AccountStore(repo)..load(),
        ),
        ChangeNotifierProvider<TransactionStore>(
          create: (_) => TransactionStore(repo)..load(),
        ),
        ChangeNotifierProvider<SpendingStore>(
          create: (_) => SpendingStore(localStore)..load(),
        ),
        ChangeNotifierProvider<FavouriteStore>(
          create: (_) => FavouriteStore(localStore)..load(),
        ),
        ChangeNotifierProvider<ScheduleStore>(
          create: (_) => ScheduleStore(localStore)..load(),
        ),
        // Depends on both stores, so it is built from them rather than
        // rebuilding its own copies.
        ProxyProvider2<AccountStore, TransactionStore, TransferService>(
          update: (_, accounts, transactions, _) => TransferService(
            accounts: accounts,
            transactions: transactions,
          ),
        ),
      ],
      child: const _App(),
    );
  }
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    final mode = context.select<ThemeController?, ThemeMode>(
      (controller) => controller?.mode ?? ThemeMode.system,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Newtronic Banking',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      themeAnimationDuration: Motion.medium,
      themeAnimationCurve: Motion.move,
      initialRoute: SplashScreen.routeName,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case SplashScreen.routeName:
            return MaterialPageRoute(builder: (_) => const SplashScreen());

          case AuthenticationScreen.routeName:
            return MyApp._fadeRoute(const AuthenticationScreen());

          case HomeScreen.routeName:
            final id = settings.arguments as int;
            return MyApp._fadeRoute(HomeScreen(id: id));

          case ProfileScreen.routeName:
            return MaterialPageRoute(builder: (_) => const ProfileScreen());

          case TransactionScreen.routeName:
            final userId = settings.arguments as int;
            return MaterialPageRoute(
              builder: (_) => TransactionScreen(userId: userId),
            );

          case AddTransactionScreen.routeName:
            // Accepts a bare user id, or that plus a favourite to prefill from.
            final arguments = settings.arguments;
            final prefill =
                arguments is TransferArgs ? arguments.prefill : null;
            final userId = arguments is TransferArgs
                ? arguments.userId
                : arguments as int;
            return MaterialPageRoute(
              builder: (_) => AddTransactionScreen(
                userId: userId,
                prefill: prefill,
              ),
            );

          case StatusTransactionScreen.routeName:
            final receipt = settings.arguments as TransferReceipt;
            return MyApp._fadeRoute(StatusTransactionScreen(receipt: receipt));

          default:
            return MaterialPageRoute(builder: (_) => const SplashScreen());
        }
      },
    );
  }
}
