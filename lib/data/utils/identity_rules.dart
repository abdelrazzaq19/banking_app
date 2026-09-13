/// The rules for a name, a username and an email address.
///
/// Shared rather than written twice. These used to live privately inside the
/// sign-up screen; once the profile screen could edit the same fields, two
/// copies would have been free to drift — and a name the profile accepted but
/// sign-up rejected is the kind of disagreement nobody notices until a user
/// cannot recreate their own account.
///
/// Each returns null when the value is fine, or the sentence to show when it
/// is not.
library;

/// Names run 3 to 50 characters, letters and spaces.
String? validateFullName(String value) {
  final withoutSpaces = value.replaceAll(' ', '');
  if (withoutSpaces.isEmpty) return 'Full Name is required';
  if (withoutSpaces.length < 3 || withoutSpaces.length > 50) {
    return 'Full Name must be 3 to 50 characters';
  }
  if (withoutSpaces.contains(RegExp(r'[0-9]')) ||
      withoutSpaces.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
    return 'Full Name must be text only';
  }
  return null;
}

/// Usernames run 6 to 12 alphanumeric characters.
String? validateUsername(String value) {
  if (value.isEmpty) return 'Username is required';
  // Previously `length < 6 && length > 12`, which no string can satisfy, so
  // the length rule never fired.
  if (value.length < 6 || value.length > 12) {
    return 'Username must be 6 to 12 characters';
  }
  if (value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
    return 'Username must be alphanumeric only';
  }
  return null;
}

/// A shape check, not a deliverability check.
///
/// Nothing here can tell whether an address receives mail; the pattern only
/// catches the typo that is obvious on the page.
String? validateEmail(String value) {
  if (value.isEmpty) return 'Email is required';
  if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(value)) {
    return 'Check your format email';
  }
  return null;
}
