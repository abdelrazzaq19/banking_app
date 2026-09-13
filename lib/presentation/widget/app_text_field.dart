import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/styles/typography.dart';

/// The two field shapes the app uses.
enum AppFieldStyle {
  /// Pill-shaped and filled. Auth forms, search boxes.
  filled,

  /// A single rule under the text. The transfer form, where fields read as
  /// parts of one document rather than separate controls.
  underlined,
}

/// The app's text field.
///
/// Wraps [TextField] so every input gets the same colours, error treatment and
/// semantics. [errorText] drives both the message and the error-coloured
/// border, so a field cannot show one without the other.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.errorText,
    this.labelText,
    this.helperText,
    this.style = AppFieldStyle.filled,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.onChanged,
    this.onTap,
    this.onSubmitted,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.useTabularFigures = false,
    this.semanticLabel,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String hintText;

  /// Non-empty means the field is in its error state. Null or empty means it is
  /// not — callers should not have to keep a separate `hasError` flag.
  final String? errorText;

  final String? labelText;
  final String? helperText;
  final AppFieldStyle style;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmitted;
  final bool readOnly;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final int? maxLines;
  final TextCapitalization textCapitalization;

  /// Use monospaced digits — for amounts and account numbers, so the figures
  /// do not shift as they are typed.
  final bool useTabularFigures;

  /// Announced to a screen reader in place of [hintText].
  final String? semanticLabel;

  final TextInputAction? textInputAction;

  bool get hasError => errorText != null && errorText!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final colors = context.colors;
    final isFilled = style == AppFieldStyle.filled;

    final baseTextStyle = isFilled ? bodyText2 : subHeadline5;
    final textStyle = (useTabularFigures
            ? numeric(baseTextStyle)
            : baseTextStyle)
        .copyWith(
      color: enabled ? scheme.onSurface : colors.subtleText,
    );

    InputBorder border(Color color, {double width = 1}) => isFilled
        ? OutlineInputBorder(
            borderRadius: Radii.pillAll,
            borderSide: BorderSide(color: color, width: width),
          )
        : UnderlineInputBorder(
            borderSide: BorderSide(color: color, width: width),
          );

    return Semantics(
      textField: true,
      label: semanticLabel ?? labelText ?? hintText,
      enabled: enabled,
      child: ExcludeSemantics(
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: autofocus,
          enabled: enabled,
          readOnly: readOnly,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onTap: onTap,
          onSubmitted: onSubmitted,
          maxLines: obscureText ? 1 : maxLines,
          style: textStyle,
          cursorColor: scheme.primary,
          decoration: InputDecoration(
            filled: isFilled,
            fillColor: colors.mutedFill,
            hintText: hintText,
            hintStyle: bodyText2.copyWith(color: colors.subtleText),
            labelText: labelText,
            labelStyle: bodyText2.copyWith(color: colors.subtleText),
            helperText: helperText,
            helperStyle: bodyText3.copyWith(color: colors.subtleText),
            errorText: hasError ? errorText : null,
            errorStyle: bodyText3.copyWith(color: scheme.error),
            errorMaxLines: 2,
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, color: colors.subtleText),
            suffixIcon: suffix,
            // 48pt minimum on the trailing control, which is usually a tappable
            // visibility or clear button.
            suffixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isFilled ? Insets.md : 0,
              vertical: Insets.sm,
            ),
            border: border(colors.mutedBorder),
            enabledBorder: border(colors.mutedBorder),
            disabledBorder: border(colors.mutedBorder),
            focusedBorder: border(scheme.primary, width: 2),
            errorBorder: border(scheme.error),
            focusedErrorBorder: border(scheme.error, width: 2),
          ),
        ),
      ),
    );
  }
}

/// The show/hide control for a password field.
///
/// Split out because it appears three times across the auth form and each copy
/// previously reimplemented its own icon, colour and (missing) tooltip.
class PasswordVisibilityToggle extends StatelessWidget {
  const PasswordVisibilityToggle({
    super.key,
    required this.isObscured,
    required this.onToggle,
  });

  final bool isObscured;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onToggle,
      tooltip: isObscured ? 'Show password' : 'Hide password',
      icon: Icon(
        isObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
        color: context.colors.subtleText,
      ),
    );
  }
}
