/// How much resistance a password offers, as shown by the strength meter.
enum PasswordStrength {
  /// Nothing typed yet.
  none,
  weak,
  fair,
  good,
  strong;

  String get label => switch (this) {
        PasswordStrength.none => '',
        PasswordStrength.weak => 'Weak',
        PasswordStrength.fair => 'Fair',
        PasswordStrength.good => 'Good',
        PasswordStrength.strong => 'Strong',
      };

  /// How much of the meter to fill, 0 to 1.
  double get fraction => switch (this) {
        PasswordStrength.none => 0,
        PasswordStrength.weak => 0.25,
        PasswordStrength.fair => 0.5,
        PasswordStrength.good => 0.75,
        PasswordStrength.strong => 1,
      };

  /// Whether the password clears every sign-up rule.
  ///
  /// [PasswordStrength.good] is the floor, not `fair`: `weak` and `fair` both
  /// describe a password that is still missing a rule, and only report how far
  /// along it is. Anchoring acceptance at `fair` let `ABCDEFGH1` — three rules
  /// of five — read as acceptable while the form rejected it.
  bool get isAcceptable => index >= PasswordStrength.good.index;
}

/// A single sign-up password rule, and how to test it.
class PasswordRequirement {
  const PasswordRequirement({
    required this.description,
    required this.isSatisfiedBy,
    required this.failureMessage,
  });

  /// Shown in the checklist under the field.
  final String description;

  final bool Function(String password) isSatisfiedBy;

  /// Shown as the field's error when this is the first unmet rule.
  final String failureMessage;
}

final List<PasswordRequirement> passwordRequirements = [
  PasswordRequirement(
    description: 'At least 8 characters',
    isSatisfiedBy: (password) => password.length >= 8,
    failureMessage: 'Password must be at least 8 characters',
  ),
  PasswordRequirement(
    description: 'An uppercase letter',
    isSatisfiedBy: (password) => password.contains(RegExp(r'[A-Z]')),
    failureMessage: 'Password needs an uppercase letter',
  ),
  PasswordRequirement(
    description: 'A lowercase letter',
    isSatisfiedBy: (password) => password.contains(RegExp(r'[a-z]')),
    failureMessage: 'Password needs a lowercase letter',
  ),
  PasswordRequirement(
    description: 'A number',
    isSatisfiedBy: (password) => password.contains(RegExp(r'[0-9]')),
    failureMessage: 'Password needs a number',
  ),
  PasswordRequirement(
    description: 'A symbol',
    isSatisfiedBy: (password) =>
        password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\\[\];' "'" r'`~]')),
    failureMessage: 'Password needs a symbol',
  ),
];

/// The first rule [password] fails, or null when it satisfies all of them.
PasswordRequirement? firstUnmetRequirement(String password) {
  for (final requirement in passwordRequirements) {
    if (!requirement.isSatisfiedBy(password)) return requirement;
  }
  return null;
}

/// Scores [password] against the sign-up rules, plus a bonus for real length.
///
/// Deliberately shares [passwordRequirements] with validation, so the meter can
/// never say "Strong" about a password the form then rejects.
PasswordStrength evaluatePasswordStrength(String password) {
  if (password.isEmpty) return PasswordStrength.none;

  final met = passwordRequirements
      .where((requirement) => requirement.isSatisfiedBy(password))
      .length;

  if (met < passwordRequirements.length) {
    // Still missing a rule. `weak` and `fair` only describe how much progress
    // has been made; neither counts as acceptable.
    return met <= 2 ? PasswordStrength.weak : PasswordStrength.fair;
  }

  // Every rule met, so the password is valid. Beyond that, length is what
  // separates an adequate password from a genuinely resistant one.
  return password.length >= 14 ? PasswordStrength.strong : PasswordStrength.good;
}
