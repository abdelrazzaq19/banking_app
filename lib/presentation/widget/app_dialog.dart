import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/presentation/widget/app_button.dart';

/// Lottie files used by the dialogs, named so call sites stop passing paths.
abstract final class DialogAnimation {
  static const String loading = 'lib/assets/lotties/lottieLoading.json';
  static const String success = 'lib/assets/lotties/lottieSuccess.json';
  static const String failure = 'lib/assets/lotties/lottieFailed.json';
  static const String question = 'lib/assets/lotties/lottieAsk.json';
}

/// The shell every dialog in the app shares: an animation, a message, and
/// optional actions underneath.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.animation,
    required this.message,
    this.actions = const <Widget>[],
    this.animationSize = 140,
  });

  final String animation;
  final String message;
  final List<Widget> actions;
  final double animationSize;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: Radii.mdAll),
      child: Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LottieBuilder.asset(
              animation,
              height: animationSize,
              width: animationSize,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: Insets.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: Insets.lg),
              ...actions,
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows a blocking "please wait" dialog. Dismiss it with [dismissAppDialog].
Future<void> showLoadingDialog(
  BuildContext context, {
  String message = 'Please wait...',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppDialog(animation: DialogAnimation.loading, message: message),
  );
}

/// Pops the topmost dialog route, if one is open.
void dismissAppDialog(BuildContext context) {
  final navigator = Navigator.of(context, rootNavigator: true);
  if (navigator.canPop()) navigator.pop();
}

/// Shows the success animation, then runs [onDismissed] once it has been seen.
///
/// The dialog is closed *before* [onDismissed] fires, so a caller that navigates
/// never leaves a dead dialog route underneath the new screen.
void showSuccessDialog(
  BuildContext context, {
  required String message,
  VoidCallback? onDismissed,
  Duration duration = const Duration(seconds: 2),
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppDialog(animation: DialogAnimation.success, message: message),
  );
  Future.delayed(duration, () {
    if (!context.mounted) return;
    dismissAppDialog(context);
    onDismissed?.call();
  });
}

/// Shows a failure animation that dismisses itself.
void showErrorDialog(
  BuildContext context, {
  required String message,
  Duration duration = const Duration(seconds: 2),
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppDialog(animation: DialogAnimation.failure, message: message),
  );
  Future.delayed(duration, () {
    if (!context.mounted) return;
    dismissAppDialog(context);
  });
}

/// Asks the user to confirm something.
///
/// Resolves to `true` when confirmed and `false` when dismissed or cancelled —
/// so callers can `await` the answer instead of passing a callback and
/// juggling the dialog's own route themselves.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String message,
  String confirmLabel = 'Yes',
  String cancelLabel = 'No',
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AppDialog(
      animation: DialogAnimation.question,
      message: message,
      animationSize: 88,
      actions: [
        AppButton(
          label: confirmLabel,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
        const SizedBox(height: Insets.xs),
        AppButton(
          label: cancelLabel,
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
      ],
    ),
  );
  return result ?? false;
}
