import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:newtronic_banking/core/theme/app_theme.dart';
import 'package:newtronic_banking/core/theme/motion.dart';
import 'package:newtronic_banking/core/theme/theme_controller.dart';
import 'package:newtronic_banking/data/model/transfer_receipt.dart';
import 'package:newtronic_banking/presentation/screen/auth/authentication_screen.dart';
import 'package:newtronic_banking/presentation/screen/main/home_screen.dart';
import 'package:newtronic_banking/presentation/screen/splash_screen.dart';
import 'package:newtronic_banking/presentation/screen/transactions/add_transaction_screen.dart';
import 'package:newtronic_banking/presentation/screen/transactions/status_transaction_screen.dart';
import 'package:newtronic_banking/presentation/screen/transactions/transaction_screen.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Date formatting is used on screens that can render before any screen-level
  // initialisation runs, so the locale data is loaded once up front.
  await initializeDateFormatting('id_ID', null);
  final themeController = await ThemeController.load();
  runApp(MyApp(themeController: themeController));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.themeController});

  /// Injected so tests can supply their own; built in `main` for the real app.
  final ThemeController? themeController;

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
    if (controller == null) return const _App();

    return ChangeNotifierProvider<ThemeController>.value(
      value: controller,
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

          case TransactionScreen.routeName:
            final userId = settings.arguments as int;
            return MaterialPageRoute(
              builder: (_) => TransactionScreen(userId: userId),
            );

          case AddTransactionScreen.routeName:
            final userId = settings.arguments as int;
            return MaterialPageRoute(
              builder: (_) => AddTransactionScreen(userId: userId),
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
