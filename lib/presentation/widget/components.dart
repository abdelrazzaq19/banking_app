import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/styles/typography.dart';

// Legacy layout and input helpers.
//
// These predate the widget kit in `app_widgets.dart` and remain only while the
// screens are moved over one at a time. New code should use `AppButton`,
// `AppTextField` and friends; nothing new should be added here.

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

/// Superseded by [AppButton].
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

/// Superseded by [AppTextField].
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
