import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// What a field means, which is what its validation keys off.
///
/// The form used to address fields by list index — `field == 3 || field == 4`
/// meant "the password ones" — so reordering the form would have silently moved
/// the rules to the wrong inputs.
enum AuthFieldRole {
  fullName,
  username,
  email,
  password,
  confirmPassword,

  /// Log-in accepts either an email or a username in one field.
  identifier,
}

/// A declarative description of one field on an auth form.
@immutable
class AuthFieldSpec {
  const AuthFieldSpec({
    required this.role,
    required this.hintText,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.denySpaces = false,
    this.autofillHints = const <String>[],
  });

  final AuthFieldRole role;
  final String hintText;
  final IconData icon;
  final TextInputType keyboardType;

  /// Obscures the text and adds a per-field visibility toggle.
  final bool isPassword;

  /// Blocks whitespace as it is typed. For usernames and emails, where a
  /// trailing space is only ever a mistake.
  final bool denySpaces;

  final List<String> autofillHints;

  List<TextInputFormatter> get inputFormatters => denySpaces
      ? [FilteringTextInputFormatter.deny(RegExp(r'\s'))]
      : const <TextInputFormatter>[];
}

const List<AuthFieldSpec> logInFields = [
  AuthFieldSpec(
    role: AuthFieldRole.identifier,
    hintText: 'Email or Username',
    icon: Icons.person_rounded,
    denySpaces: true,
    autofillHints: [AutofillHints.username],
  ),
  AuthFieldSpec(
    role: AuthFieldRole.password,
    hintText: 'Password',
    icon: Icons.lock_rounded,
    keyboardType: TextInputType.visiblePassword,
    isPassword: true,
    autofillHints: [AutofillHints.password],
  ),
];

const List<AuthFieldSpec> signUpFields = [
  AuthFieldSpec(
    role: AuthFieldRole.fullName,
    hintText: 'Full Name',
    icon: Icons.person_2_rounded,
    keyboardType: TextInputType.name,
    autofillHints: [AutofillHints.name],
  ),
  AuthFieldSpec(
    role: AuthFieldRole.username,
    hintText: 'Username',
    icon: Icons.verified_user_rounded,
    keyboardType: TextInputType.name,
    denySpaces: true,
    autofillHints: [AutofillHints.newUsername],
  ),
  AuthFieldSpec(
    role: AuthFieldRole.email,
    hintText: 'Email',
    icon: Icons.email_rounded,
    keyboardType: TextInputType.emailAddress,
    denySpaces: true,
    autofillHints: [AutofillHints.email],
  ),
  AuthFieldSpec(
    role: AuthFieldRole.password,
    hintText: 'Password',
    icon: Icons.lock_rounded,
    keyboardType: TextInputType.visiblePassword,
    isPassword: true,
    autofillHints: [AutofillHints.newPassword],
  ),
  AuthFieldSpec(
    role: AuthFieldRole.confirmPassword,
    hintText: 'Confirm Password',
    icon: Icons.lock_reset_rounded,
    keyboardType: TextInputType.visiblePassword,
    isPassword: true,
  ),
];
