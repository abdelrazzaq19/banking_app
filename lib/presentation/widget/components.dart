import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/motion.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/styles/typography.dart';

SizedBox customSpaceHorizontal(double width) => SizedBox(width: width);

SizedBox customSpaceVertical(double height) => SizedBox(height: height);

Text customText({
  required String textValue,
  TextStyle? textStyle,
  TextAlign? textAlign,
  int? maxLines,
  TextOverflow? overflow,
}) {
  return Text(
    textValue,
    style: textStyle ?? headline1,
    textAlign: textAlign ?? TextAlign.start,
    maxLines: maxLines,
    overflow: overflow,
  );
}

InkWell customButton({
  required VoidCallback? buttonOnTap,
  required String buttonText,
  required Color buttonFirstGradientColor,
  required Color buttonSecondGradientColor,
  BorderRadius? buttonBorderRadius,
  EdgeInsetsGeometry? buttonPadding,
  TextStyle? textStyles,
  Color? textColor,
  double? buttonWidth,
  Widget? buttonLeftIcon,
  Widget? buttonRightIcon,
  bool isButtonIcon = false,
}) {
  final borderRadius = buttonBorderRadius ?? Radii.pillAll;
  return InkWell(
    onTap: buttonOnTap,
    borderRadius: borderRadius,
    child: Container(
      width: buttonWidth ?? double.infinity,
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          colors: [buttonFirstGradientColor, buttonSecondGradientColor],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      padding: buttonPadding ??
          const EdgeInsets.symmetric(
            horizontal: Insets.xl,
            vertical: Insets.sm,
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: isButtonIcon
            ? MainAxisAlignment.spaceEvenly
            : MainAxisAlignment.center,
        children: [
          ?buttonLeftIcon,
          customText(
            textValue: buttonText,
            textStyle: textStyles ??
                headline4.copyWith(color: textColor ?? Colors.white),
          ),
          ?buttonRightIcon,
        ],
      ),
    ),
  );
}

/// A text field styled from the active theme.
///
/// [context] is required because the colours come from the theme rather than a
/// fixed palette, which is what lets the field render correctly in dark mode.
TextField customTextField(
  BuildContext context, {
  required TextEditingController controller,
  required String hintText,
  required String errorText,
  List<TextInputFormatter>? inputFormatters,
  ValueChanged<String>? onChanged,
  VoidCallback? onTap,
  bool obscureText = false,
  TextInputType keyboardType = TextInputType.text,
  IconData? prefixIcon,
  Widget? suffixIcon,
  bool isFilled = false,
}) {
  final scheme = context.scheme;
  final colors = context.colors;

  return TextField(
    controller: controller,
    obscureText: obscureText,
    keyboardType: keyboardType,
    onChanged: onChanged,
    onTap: onTap,
    inputFormatters: inputFormatters,
    style: bodyText2.copyWith(color: scheme.onSurface),
    cursorColor: scheme.primary,
    decoration: InputDecoration(
      errorText: errorText.isEmpty ? null : errorText,
      filled: isFilled,
      fillColor: colors.mutedFill,
      hintText: hintText,
      hintStyle: bodyText2.copyWith(color: colors.subtleText),
      prefixIcon: Icon(
        prefixIcon ?? Icons.person_rounded,
        color: colors.subtleText,
      ),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: Radii.pillAll,
        borderSide: BorderSide(color: colors.mutedBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: Radii.pillAll,
        borderSide: BorderSide(color: colors.mutedBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: Radii.pillAll,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: Radii.pillAll,
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: Radii.pillAll,
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.xs,
      ),
    ),
  );
}

Future<void> customDialog(
  BuildContext context, {
  required String animationIcon,
  required String textDialog,
}) {
  return showDialog<void>(
    barrierDismissible: false,
    context: context,
    builder: (context) => Dialog(
      backgroundColor: context.scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: Radii.mdAll),
      child: Padding(
        padding: const EdgeInsets.all(Insets.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LottieBuilder.asset(
              animationIcon,
              height: 140,
              width: 140,
              fit: BoxFit.cover,
            ),
            customSpaceVertical(Insets.xs),
            customText(
              textValue: textDialog,
              textStyle: headline4.copyWith(color: context.scheme.onSurface),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

void showLoadingDialog(BuildContext context) {
  customDialog(
    context,
    animationIcon: 'lib/assets/lotties/lottieLoading.json',
    textDialog: 'Please wait...',
  );
}

/// Shows the success animation, then runs [onAction] once it has been seen.
///
/// The dialog is dismissed before [onAction] runs, so the caller never navigates
/// on top of a dialog route that is still on the stack.
void showSuccessDialog(
  BuildContext context, {
  required String message,
  required VoidCallback onAction,
}) {
  customDialog(
    context,
    animationIcon: 'lib/assets/lotties/lottieSuccess.json',
    textDialog: message,
  );
  Future.delayed(const Duration(seconds: 2), () {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    onAction();
  });
}

void showErrorDialog(BuildContext context, {required String message}) {
  customDialog(
    context,
    animationIcon: 'lib/assets/lotties/lottieFailed.json',
    textDialog: message,
  );
  Future.delayed(const Duration(seconds: 2), () {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  });
}

Future<void> customDialogWithButton(
  BuildContext context, {
  required String dialogTextValue,
  required VoidCallback dialogAction,
}) {
  return showDialog<void>(
    barrierDismissible: false,
    context: context,
    builder: (dialogContext) {
      final scheme = dialogContext.scheme;
      final colors = dialogContext.colors;
      return Dialog(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: Radii.mdAll),
        child: Container(
          width: MediaQuery.of(dialogContext).size.width * 0.65,
          padding: const EdgeInsets.all(Insets.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LottieBuilder.asset(
                'lib/assets/lotties/lottieAsk.json',
                height: 80,
                width: 80,
                fit: BoxFit.cover,
              ),
              customSpaceVertical(Insets.md),
              customText(
                textValue: dialogTextValue,
                textStyle: headline4.copyWith(color: scheme.onSurface),
                textAlign: TextAlign.center,
              ),
              customSpaceVertical(Insets.md),
              Column(
                children: List.generate(
                  2,
                  (buttonIndex) {
                    final isConfirm = buttonIndex == 0;
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        vertical: Insets.xxs,
                      ),
                      child: customButton(
                        buttonOnTap: () {
                          if (isConfirm) {
                            dialogAction();
                          } else {
                            Navigator.pop(dialogContext);
                          }
                        },
                        buttonBorderRadius: Radii.xsAll,
                        buttonText: isConfirm ? 'Yes' : 'No',
                        buttonFirstGradientColor:
                            isConfirm ? scheme.primary : colors.mutedFill,
                        buttonSecondGradientColor:
                            isConfirm ? colors.accent : colors.mutedFill,
                        textColor: isConfirm
                            ? scheme.onPrimary
                            : scheme.onSurface,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Fades and lifts [child] into place, offset by its position in a list.
///
/// Used for the staggered reveals on the home and transaction screens.
class Reveal extends StatelessWidget {
  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 16,
  });

  final Widget child;

  /// Position in the group; each step delays the animation by [Motion.stagger].
  final int index;

  /// How far the child travels upward as it fades in.
  final double offset;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Motion.medium + Motion.stagger * index,
      curve: Motion.enter,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - value) * offset),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
