import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newtronic_banking/core/theme/app_theme.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';

/// Hosts [child] in a real themed app so widgets resolve the same colours and
/// text styles they will at runtime.
Widget _host(Widget child, {ThemeMode mode = ThemeMode.light}) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: mode,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('AppButton', () {
    testWidgets('fires its callback when enabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(
        AppButton(label: 'Transfer', onPressed: () => taps++),
      ));

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('a null callback disables it and blocks taps', (tester) async {
      await tester.pumpWidget(_host(
        const AppButton(label: 'Transfer', onPressed: null),
      ));

      final semantics = tester.getSemantics(find.byType(AppButton));
      expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);

      // Nothing to assert a callback against — the point is that tapping a
      // disabled button must not throw or fire anything.
      await tester.tap(find.byType(AppButton));
      await tester.pump();
    });

    testWidgets('a disabled button is styled differently from an enabled one',
        (tester) async {
      await tester.pumpWidget(_host(
        const Column(
          children: [
            AppButton(label: 'Enabled', onPressed: _noop, expand: false),
            AppButton(label: 'Disabled', onPressed: null, expand: false),
          ],
        ),
      ));

      final enabled = tester.widget<Text>(find.text('Enabled'));
      final disabled = tester.widget<Text>(find.text('Disabled'));
      expect(enabled.style?.color, isNot(disabled.style?.color));
    });

    testWidgets('loading swaps the label for a spinner and blocks taps',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(
        AppButton(label: 'Transfer', isLoading: true, onPressed: () => taps++),
      ));

      expect(find.text('Transfer'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(AppButton));
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('meets the 48pt minimum tap target', (tester) async {
      await tester.pumpWidget(_host(
        const AppButton(
          label: 'Small',
          size: AppButtonSize.medium,
          expand: false,
          onPressed: _noop,
        ),
      ));

      expect(tester.getSize(find.byType(AppButton)).height,
          greaterThanOrEqualTo(48));
    });

    testWidgets('exposes a button semantic with its label', (tester) async {
      await tester.pumpWidget(_host(
        const AppButton(
          label: 'Save',
          semanticLabel: 'Save as favourite',
          onPressed: _noop,
        ),
      ));

      final semantics = tester.getSemantics(find.byType(AppButton));
      expect(semantics.label, 'Save as favourite');
      expect(semantics.flagsCollection.isButton, isTrue);
    });

    testWidgets('renders leading and trailing icons', (tester) async {
      await tester.pumpWidget(_host(
        const AppButton(
          label: 'QRIS',
          icon: Icons.qr_code_rounded,
          trailingIcon: Icons.chevron_right_rounded,
          onPressed: _noop,
        ),
      ));

      expect(find.byIcon(Icons.qr_code_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });
  });

  group('AppTextField', () {
    testWidgets('shows the error message when errorText is set',
        (tester) async {
      await tester.pumpWidget(_host(
        AppTextField(
          controller: TextEditingController(),
          hintText: 'Account Number',
          errorText: 'Account number must be 12 digits',
        ),
      ));

      expect(find.text('Account number must be 12 digits'), findsOneWidget);
    });

    testWidgets('an empty errorText is not an error state', (tester) async {
      await tester.pumpWidget(_host(
        AppTextField(
          controller: TextEditingController(),
          hintText: 'Account Number',
          errorText: '',
        ),
      ));

      final field = tester.widget<AppTextField>(find.byType(AppTextField));
      expect(field.hasError, isFalse);
      expect(find.text('Account Number'), findsOneWidget);
    });

    testWidgets('reports typed text through onChanged', (tester) async {
      final controller = TextEditingController();
      String? seen;
      await tester.pumpWidget(_host(
        AppTextField(
          controller: controller,
          hintText: 'Recipient Name',
          onChanged: (value) => seen = value,
        ),
      ));

      await tester.enterText(find.byType(TextField), 'Siti Rahayu');
      expect(seen, 'Siti Rahayu');
      expect(controller.text, 'Siti Rahayu');
    });

    testWidgets('carries a text-field semantic label', (tester) async {
      await tester.pumpWidget(_host(
        AppTextField(
          controller: TextEditingController(),
          hintText: 'Search',
          semanticLabel: 'Search banks',
        ),
      ));

      final semantics = tester.getSemantics(find.byType(AppTextField));
      expect(semantics.label, 'Search banks');
    });
  });

  group('PasswordVisibilityToggle', () {
    testWidgets('swaps its icon and tooltip with the obscured state',
        (tester) async {
      await tester.pumpWidget(_host(
        PasswordVisibilityToggle(isObscured: true, onToggle: () {}),
      ));
      expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);

      await tester.pumpWidget(_host(
        PasswordVisibilityToggle(isObscured: false, onToggle: () {}),
      ));
      expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
    });
  });

  group('GlassCard', () {
    testWidgets('renders its child', (tester) async {
      await tester.pumpWidget(_host(
        const GlassCard(width: 240, height: 160, child: Text('Rp 5.000.000')),
      ));

      expect(find.text('Rp 5.000.000'), findsOneWidget);
    });

    testWidgets('is a button only when given an onTap', (tester) async {
      await tester.pumpWidget(_host(
        const GlassCard(width: 240, height: 160, child: SizedBox.shrink()),
      ));
      expect(find.byType(GestureDetector), findsNothing);

      var taps = 0;
      await tester.pumpWidget(_host(
        GlassCard(
          width: 240,
          height: 160,
          onTap: () => taps++,
          semanticLabel: 'BlueSky account',
          child: const SizedBox.shrink(),
        ),
      ));

      await tester.tap(find.byType(GlassCard));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('SectionHeader', () {
    testWidgets('marks its title as a heading', (tester) async {
      await tester.pumpWidget(_host(
        const SectionHeader(title: 'Recent Activities'),
      ));

      final semantics = tester.getSemantics(find.text('Recent Activities'));
      expect(semantics.flagsCollection.isHeader, isTrue);
    });

    testWidgets('shows its action only when a handler is supplied',
        (tester) async {
      await tester.pumpWidget(_host(
        const SectionHeader(title: 'Recent', actionLabel: 'See all'),
      ));
      expect(find.text('See all'), findsNothing);

      var taps = 0;
      await tester.pumpWidget(_host(
        SectionHeader(
          title: 'Recent',
          actionLabel: 'See all',
          onActionPressed: () => taps++,
        ),
      ));

      await tester.tap(find.text('See all'));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('showPickerSheet', () {
    Future<String?> openSheet(WidgetTester tester, List<String> items) async {
      String? picked;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                picked = await showPickerSheet<String>(
                  context: context,
                  title: 'Select Bank',
                  items: items,
                  matches: (item, query) =>
                      item.toLowerCase().contains(query.toLowerCase()),
                  itemBuilder: (context, item, query) => ListTile(title: Text(item)),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return picked;
    }

    testWidgets('opens with the full list, not an empty state', (tester) async {
      await openSheet(tester, ['Bank Mandiri', 'Bank BCA', 'Bank Danamon']);

      expect(find.textContaining('not found'), findsNothing);
      expect(find.text('Bank Mandiri'), findsOneWidget);
      expect(find.text('Bank Danamon'), findsOneWidget);
    });

    testWidgets('filters as you type and reports no matches', (tester) async {
      await openSheet(tester, ['Bank Mandiri', 'Bank BCA', 'Bank Danamon']);

      // The search is debounced, and a pending Timer does not schedule a
      // frame, so pumpAndSettle alone can return before it fires.
      await tester.enterText(find.byType(TextField), 'danamon');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.text('Bank Danamon'), findsOneWidget);
      expect(find.text('Bank Mandiri'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.textContaining('not found'), findsOneWidget);
    });

    testWidgets('returns the tapped item to the caller', (tester) async {
      // The sheet resolves to a value rather than mutating caller state, which
      // is what the two hand-rolled copies it replaced got wrong.
      String? picked;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                picked = await showPickerSheet<String>(
                  context: context,
                  title: 'Select Bank',
                  items: const ['Bank Mandiri', 'Bank Danamon'],
                  matches: (item, query) => item.contains(query),
                  itemBuilder: (context, item, query) => ListTile(title: Text(item)),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bank Danamon'));
      await tester.pumpAndSettle();

      expect(picked, 'Bank Danamon');
    });
  });

  group('staggeredReveal', () {
    testWidgets('wraps every child and increases the delay', (tester) async {
      final revealed = staggeredReveal(const [Text('a'), Text('b'), Text('c')]);

      expect(revealed, hasLength(3));
      expect((revealed[0] as Reveal).index, 0);
      expect((revealed[2] as Reveal).index, 2);

      await tester.pumpWidget(_host(Column(children: revealed)));
      await tester.pumpAndSettle();

      expect(find.text('a'), findsOneWidget);
      expect(find.text('c'), findsOneWidget);
    });

    testWidgets('renders children immediately when disabled', (tester) async {
      await tester.pumpWidget(_host(
        Column(children: staggeredReveal(const [Text('now')], enabled: false)),
      ));
      await tester.pump();

      expect(find.text('now'), findsOneWidget);
      expect(find.byType(Opacity), findsNothing);
    });
  });

  group('dialogs', () {
    testWidgets('showConfirmDialog resolves true on confirm and false on cancel',
        (tester) async {
      Future<bool?> run(String tapLabel) async {
        bool? answer;
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  answer = await showConfirmDialog(
                    context,
                    message: 'Are you sure?',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ));

        await tester.tap(find.text('open'));
        // Lottie animations loop, so pumpAndSettle would never return here.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        await tester.tap(find.text(tapLabel));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        return answer;
      }

      expect(await run('Yes'), isTrue);
      expect(await run('No'), isFalse);
    });
  });
}

void _noop() {}
