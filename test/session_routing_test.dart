import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:newtronic_banking/presentation/screen/auth/authentication_screen.dart';
import 'package:newtronic_banking/presentation/screen/main/home_screen.dart';
import 'package:newtronic_banking/presentation/screen/main/profile_screen.dart';
import 'package:newtronic_banking/presentation/screen/splash_screen.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';

import 'support/test_harness.dart';

/// Records where the app was sent, without building the destination screens.
class _RouteSpy {
  final List<String> names = [];
  Object? lastArguments;
}

/// Pumps the splash screen with a stub route table, so the assertions are about
/// routing rather than about whatever Home happens to render.
Future<_RouteSpy> _pumpSplash(TestBackend backend, WidgetTester tester) async {
  useMobileSurface(tester);
  final spy = _RouteSpy();

  // No initialRoute: naming one makes Flutter build the implicit '/' root
  // *and* the named route, which would put two SplashScreens — and two
  // navigation timers — in the initial stack.
  await tester.pumpWidget(wrapWithBackend(
    backend,
    onGenerateRoute: (settings) {
      final name = settings.name ?? Navigator.defaultRouteName;
      if (name != Navigator.defaultRouteName) {
        spy.names.add(name);
        spy.lastArguments = settings.arguments;
        return MaterialPageRoute(
          builder: (_) => Scaffold(body: Text('route:$name')),
        );
      }
      return MaterialPageRoute(builder: (_) => const SplashScreen());
    },
  ));

  await tester.pump();
  // Clear the splash hold plus the route transition.
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(milliseconds: 600));
  return spy;
}

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  group('splash routing', () {
    testWidgets('a signed-out user lands on authentication', (tester) async {
      final backend = await createTestBackend();
      final spy = await _pumpSplash(backend, tester);

      expect(spy.names, [AuthenticationScreen.routeName]);
    });

    testWidgets('a returning user goes straight to their accounts',
        (tester) async {
      final backend = await createTestBackend();
      await backend.session.signInWithCredentials(
        emailOrUsername: 'john.doe@newtronic.com',
        password: 'password123',
      );

      final spy = await _pumpSplash(backend, tester);

      // Never touches the login screen.
      expect(spy.names, [HomeScreen.routeName]);
      expect(spy.lastArguments, backend.session.userId);
    });

    testWidgets('a session whose user no longer exists is not trusted',
        (tester) async {
      final backend = await createTestBackend();
      await backend.store.writeDocument('store.session', {'userId': 99999});
      await backend.session.restore();

      final spy = await _pumpSplash(backend, tester);

      expect(spy.names, [AuthenticationScreen.routeName]);
    });
  });

  group('profile', () {
    Future<TestBackend> pumpProfile(WidgetTester tester) async {
      useMobileSurface(tester);
      final backend = await createTestBackend();
      await backend.session.signInWithCredentials(
        emailOrUsername: 'john.doe@newtronic.com',
        password: 'password123',
      );

      // A route table, so signing out has somewhere to navigate to.
      await tester.pumpWidget(wrapWithBackend(
        backend,
        initialRoute: ProfileScreen.routeName,
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (_) => settings.name == ProfileScreen.routeName
              ? const ProfileScreen()
              : Scaffold(body: Text('route:${settings.name}')),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      return backend;
    }

    testWidgets('shows the signed-in user and their totals', (tester) async {
      final backend = await pumpProfile(tester);

      expect(find.text('John Doe'), findsWidgets);
      expect(find.text('johndoe123'), findsOneWidget);
      expect(find.text('john.doe@newtronic.com'), findsOneWidget);
      expect(
        find.text(backend.accounts.total.formattedWithSymbol),
        findsOneWidget,
      );
    });

    testWidgets('never displays a password or its hash', (tester) async {
      await pumpProfile(tester);

      final texts = find
          .byType(Text)
          .evaluate()
          .map((element) => (element.widget as Text).data ?? '')
          .join(' ');

      expect(texts.contains('password123'), isFalse);
      expect(texts.contains('pbkdf2'), isFalse);
    });

    testWidgets('signing out clears the session and returns to auth',
        (tester) async {
      final backend = await pumpProfile(tester);
      expect(backend.session.isSignedIn, isTrue);

      await tester.tap(find.widgetWithText(AppButton, 'Sign out'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Confirm the dialog.
      await tester.tap(find.widgetWithText(AppButton, 'Sign out').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(backend.session.isSignedIn, isFalse);
      expect(backend.store.readDocument('store.session'), isNull);
    });

    testWidgets('cancelling the sign-out keeps the session', (tester) async {
      final backend = await pumpProfile(tester);

      await tester.tap(find.widgetWithText(AppButton, 'Sign out'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.widgetWithText(AppButton, 'Stay'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(backend.session.isSignedIn, isTrue);
    });
  });

  group('SessionStore.currentUser', () {
    test('is null when signed out and the user when signed in', () async {
      final backend = await createTestBackend();
      expect(backend.session.currentUser, isNull);

      await backend.session.signInWithCredentials(
        emailOrUsername: 'johndoe123',
        password: 'password123',
      );

      expect(backend.session.currentUser?.name, 'John Doe');
    });
  });
}
