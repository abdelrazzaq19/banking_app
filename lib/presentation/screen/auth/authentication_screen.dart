import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/motion.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/state/session_store.dart';
import 'package:provider/provider.dart';
import 'package:newtronic_banking/data/utils/password_strength.dart';
import 'package:newtronic_banking/presentation/screen/auth/auth_field_spec.dart';
import 'package:newtronic_banking/presentation/screen/main/home_screen.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';

/// One field on the form, with everything that belongs to it in one place.
///
/// [isTouched] is what makes live validation bearable: a field stays silent
/// until the user has left it once, then updates on every keystroke. Validating
/// from the first character would flag every password as too short while it is
/// still being typed.
class _AuthField {
  _AuthField(this.spec);

  final AuthFieldSpec spec;
  final TextEditingController controller = TextEditingController();
  final FocusNode focusNode = FocusNode();

  String error = '';
  bool isTouched = false;

  /// Per field, so revealing one password does not reveal the other. They used
  /// to share a single flag.
  bool isObscured = true;

  String get value => controller.text;

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({super.key});
  static const routeName = '/authentication';

  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  static const int _pageWelcome = 0;
  static const int _pageLogIn = 1;
  static const int _pageSignUp = 2;
  static const int _pageCount = 3;

  final PageController pageController = PageController();

  late final List<_AuthField> _logInFields =
      logInFields.map(_AuthField.new).toList();
  late final List<_AuthField> _signUpFields =
      signUpFields.map(_AuthField.new).toList();

  int pageIndex = _pageWelcome;
  bool _isSubmitting = false;

  List<_AuthField> get _activeFields =>
      pageIndex == _pageSignUp ? _signUpFields : _logInFields;

  bool get _isActiveFormComplete =>
      _activeFields.every((field) => field.value.isNotEmpty);

  @override
  void initState() {
    super.initState();
    for (final field in [..._logInFields, ..._signUpFields]) {
      // Losing focus is the moment a field becomes fair game for an error.
      field.focusNode.addListener(() {
        if (field.focusNode.hasFocus || field.isTouched) return;
        setState(() {
          field.isTouched = true;
          field.error = _validate(field);
        });
      });
    }
  }

  @override
  void dispose() {
    pageController.dispose();
    for (final field in [..._logInFields, ..._signUpFields]) {
      field.dispose();
    }
    super.dispose();
  }

  void goToPage(int index) {
    FocusScope.of(context).unfocus();
    pageController.animateToPage(
      index,
      duration: Motion.medium,
      curve: Motion.move,
    );
  }

  @override
  Widget build(BuildContext context) {
    // The keyboard is treated as a layout input rather than a reason to hide
    // widgets outright: the header shrinks and the footer slides away, both
    // animated, instead of popping out of the tree mid-interaction.
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || pageIndex == _pageWelcome) return;
        goToPage(pageIndex - 1);
      },
      child: Scaffold(
        backgroundColor: context.scheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, isCollapsed: isKeyboardOpen),
              Expanded(
                child: PageView.builder(
                  controller: pageController,
                  onPageChanged: (index) => setState(() => pageIndex = index),
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _pageCount,
                  itemBuilder: (context, index) => _buildPage(context, index),
                ),
              ),
              _buildFooter(context, isHidden: isKeyboardOpen),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, {required bool isCollapsed}) {
    final isWelcome = pageIndex == _pageWelcome;

    return AnimatedSize(
      duration: Motion.fast,
      curve: Motion.move,
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: ThemeToggleButton(),
            ),
            // Collapsed, the logo shrinks to a strip instead of disappearing,
            // which keeps the screen anchored while the keyboard is up.
            AnimatedScale(
              duration: Motion.fast,
              curve: Motion.move,
              scale: isCollapsed ? 0.6 : 1,
              child: Image.asset(
                'lib/assets/images/logo.png',
                height: isCollapsed ? 36 : 64,
                fit: BoxFit.contain,
                semanticLabel: 'Newtronic Banking',
              ),
            ),
            if (!isWelcome && !isCollapsed) ...[
              const SizedBox(height: Insets.xl),
              Text(
                pageIndex == _pageLogIn ? 'Log in Now' : 'Sign Up Now',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: Insets.xs),
              Text(
                pageIndex == _pageLogIn
                    ? 'Please log in to continue using app'
                    : 'Please fill details to create an account',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: context.colors.subtleText),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// A page that fills the viewport when there is room and scrolls when the
  /// keyboard takes that room away.
  Widget _buildPage(BuildContext context, int index) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.md,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - Insets.md * 2,
          ),
          child: IntrinsicHeight(
            child: Column(
              children: [
                if (index == _pageWelcome)
                  _buildWelcome(context)
                else
                  _buildForm(context, index),
                const Spacer(),
                const SizedBox(height: Insets.lg),
                _buildPrimaryAction(context, index),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcome(BuildContext context) {
    return Column(
      children: [
        // The illustration drifts against the page as it scrolls away, which
        // gives the transition depth rather than sliding as one flat sheet.
        AnimatedBuilder(
          animation: pageController,
          builder: (context, child) {
            final page = pageController.hasClients &&
                    pageController.position.hasContentDimensions
                ? (pageController.page ?? 0)
                : 0.0;
            return Transform.translate(
              offset: Offset(page * 90, 0),
              child: Opacity(
                opacity: (1 - page).clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: Image.asset(
            'lib/assets/images/welcome.png',
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(height: Insets.xl),
        Text(
          'Welcome',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: Insets.sm),
        Text(
          'Create an account and get access to all cool stuff',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: context.colors.subtleText),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context, int index) {
    final fields = index == _pageSignUp ? _signUpFields : _logInFields;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(height: Insets.md),
          _buildField(context, fields[i]),
        ],
        if (index == _pageLogIn)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _explainNoPasswordReset,
              child: const Text('Forgot Password?'),
            ),
          ),
      ],
    );
  }

  /// Says why there is no reset, rather than doing nothing.
  ///
  /// A password here is only ever a hash in this device's own storage — there
  /// is no server holding an account to recover, and no address to send a link
  /// to. A button that silently did nothing implied otherwise.
  Future<void> _explainNoPasswordReset() async {
    await showConfirmDialog(
      context,
      message: 'Your sign-in details live only on this device, so there is '
          'nothing to email a reset link to. You can create a new account '
          'instead.',
      confirmLabel: 'Create an account',
      cancelLabel: 'Back',
    ).then((createAccount) {
      if (createAccount && mounted) goToPage(_pageSignUp);
    });
  }

  Widget _buildField(BuildContext context, _AuthField field) {
    final isNewPassword = field.spec.role == AuthFieldRole.password &&
        pageIndex == _pageSignUp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: field.controller,
          focusNode: field.focusNode,
          hintText: field.spec.hintText,
          semanticLabel: field.spec.hintText,
          prefixIcon: field.spec.icon,
          keyboardType: field.spec.keyboardType,
          inputFormatters: field.spec.inputFormatters,
          obscureText: field.spec.isPassword && field.isObscured,
          errorText: field.error,
          textInputAction: TextInputAction.next,
          onChanged: (_) => _onFieldChanged(field),
          suffix: field.spec.isPassword
              ? PasswordVisibilityToggle(
                  isObscured: field.isObscured,
                  onToggle: () => setState(
                    () => field.isObscured = !field.isObscured,
                  ),
                )
              : null,
        ),
        if (isNewPassword) PasswordStrengthMeter(password: field.value),
      ],
    );
  }

  void _onFieldChanged(_AuthField field) {
    setState(() {
      if (field.isTouched) field.error = _validate(field);

      // Confirmation depends on the password above it, so retyping the password
      // has to re-check the confirmation too.
      if (field.spec.role == AuthFieldRole.password) {
        for (final other in _signUpFields) {
          if (other.spec.role == AuthFieldRole.confirmPassword &&
              other.isTouched) {
            other.error = _validate(other);
          }
        }
      }
    });
  }

  Widget _buildPrimaryAction(BuildContext context, int index) {
    final label = switch (index) {
      _pageWelcome => 'Get Started',
      _pageLogIn => 'Log in',
      _ => 'Sign Up',
    };

    return AppButton(
      label: label,
      isLoading: _isSubmitting && index == pageIndex,
      onPressed: index == _pageWelcome || _isActiveFormComplete
          ? () => _onPrimaryPressed(index)
          : null,
    );
  }

  void _onPrimaryPressed(int index) {
    switch (index) {
      case _pageWelcome:
        goToPage(_pageSignUp);
      case _pageLogIn:
        loginFunction();
      case _pageSignUp:
        signupFunction();
    }
  }

  Widget _buildFooter(BuildContext context, {required bool isHidden}) {
    final isLogIn = pageIndex == _pageLogIn;

    return AnimatedSize(
      duration: Motion.fast,
      curve: Motion.move,
      alignment: Alignment.bottomCenter,
      child: isHidden
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: Insets.xs),
              child: Column(
                children: [
                  if (pageIndex != _pageWelcome)
                    // Wrap, not Row: the prompt plus the action overflows a
                    // narrow phone on one line, and wrapping is better than
                    // truncating either half.
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          isLogIn
                              ? "Don't have an account?"
                              : 'Already have an account?',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: context.colors.subtleText),
                        ),
                        TextButton(
                          onPressed: () =>
                              goToPage(isLogIn ? _pageSignUp : _pageLogIn),
                          child: Text(isLogIn ? 'Sign Up' : 'Log in'),
                        ),
                      ],
                    ),
                  PageDots(
                    controller: pageController,
                    count: _pageCount,
                    fallbackIndex: pageIndex,
                    onDotTapped: goToPage,
                  ),
                ],
              ),
            ),
    );
  }

  // ---------------------------------------------------------------- actions

  Future<void> loginFunction() async {
    if (!_markTouchedAndValidate(_logInFields)) return;

    setState(() => _isSubmitting = true);
    try {
      final user = await context.read<SessionStore>().signInWithCredentials(
            emailOrUsername:
                _fieldFor(_logInFields, AuthFieldRole.identifier).value,
            password: _fieldFor(_logInFields, AuthFieldRole.password).value,
          );
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (user == null) {
        showErrorDialog(context, message: 'Account not found');
        return;
      }
      showSuccessDialog(
        context,
        message: 'Login Success',
        onDismissed: () => Navigator.pushReplacementNamed(
          context,
          HomeScreen.routeName,
          arguments: user.id,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorDialog(context, message: error.toString());
    }
  }

  Future<void> signupFunction() async {
    if (!_markTouchedAndValidate(_signUpFields)) return;

    final confirmed = await showConfirmDialog(
      context,
      message: 'Are you sure want to create an account?',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSubmitting = true);
    final result = await context.read<SessionStore>().register(
          name: _fieldFor(_signUpFields, AuthFieldRole.fullName).value.trim(),
          username: _fieldFor(_signUpFields, AuthFieldRole.username).value,
          email: _fieldFor(_signUpFields, AuthFieldRole.email).value,
          password: _fieldFor(_signUpFields, AuthFieldRole.password).value,
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    // A taken name belongs on the field that caused it, not in a dialog.
    if (!result.isSuccess) {
      setState(() {
        switch (result.failure) {
          case RegistrationFailure.emailTaken:
            _fieldFor(_signUpFields, AuthFieldRole.email).error =
                'That email already has an account';
          case RegistrationFailure.usernameTaken:
            _fieldFor(_signUpFields, AuthFieldRole.username).error =
                'That username is taken';
          case null:
            break;
        }
      });
      return;
    }

    // Registration signs the new user in, so go straight to their accounts
    // rather than making them type the password they just chose.
    showSuccessDialog(
      context,
      message: 'Register Success',
      onDismissed: () => Navigator.pushReplacementNamed(
        context,
        HomeScreen.routeName,
        arguments: result.user!.id,
      ),
    );
  }

  // ------------------------------------------------------------- validation

  _AuthField _fieldFor(List<_AuthField> fields, AuthFieldRole role) =>
      fields.firstWhere((field) => field.spec.role == role);

  /// Validates every field in [fields] and reveals the results.
  ///
  /// Returns whether the form is valid.
  bool _markTouchedAndValidate(List<_AuthField> fields) {
    setState(() {
      for (final field in fields) {
        field.isTouched = true;
        field.error = _validate(field);
      }
    });
    return fields.every((field) => field.error.isEmpty);
  }

  String _validate(_AuthField field) {
    final value = field.value;
    return switch (field.spec.role) {
      AuthFieldRole.identifier =>
        value.isEmpty ? 'Email or Username is required' : '',
      AuthFieldRole.fullName => _validateFullName(value),
      AuthFieldRole.username => _validateUsername(value),
      AuthFieldRole.email => _validateEmail(value),
      AuthFieldRole.password => _validatePassword(value),
      AuthFieldRole.confirmPassword => _validateConfirmPassword(
          value,
          _fieldFor(_signUpFields, AuthFieldRole.password).value,
        ),
    };
  }

  String _validateFullName(String value) {
    final withoutSpaces = value.replaceAll(' ', '');
    if (withoutSpaces.isEmpty) return 'Full Name is required';
    if (withoutSpaces.length < 3 || withoutSpaces.length > 50) {
      return 'Full Name must be 3 to 50 characters';
    }
    if (withoutSpaces.contains(RegExp(r'[0-9]')) ||
        withoutSpaces.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Full Name must be text only';
    }
    return '';
  }

  String _validateUsername(String value) {
    if (value.isEmpty) return 'Username is required';
    // Previously `length < 6 && length > 12`, which no string can satisfy, so
    // the length rule never fired.
    if (value.length < 6 || value.length > 12) {
      return 'Username must be 6 to 12 characters';
    }
    if (value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Username must be alphanumeric only';
    }
    return '';
  }

  String _validateEmail(String value) {
    if (value.isEmpty) return 'Email is required';
    final emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!emailPattern.hasMatch(value)) return 'Check your format email';
    return '';
  }

  /// On sign-up, defers to the shared requirement list so the strength meter
  /// and the error message can never disagree. On log-in there is nothing to
  /// check but presence — an existing account's password is whatever it is.
  String _validatePassword(String value) {
    if (value.isEmpty) return 'Password is required';
    if (pageIndex != _pageSignUp) return '';
    return firstUnmetRequirement(value)?.failureMessage ?? '';
  }

  String _validateConfirmPassword(String value, String password) {
    if (value.isEmpty) return 'Confirm Password is required';
    if (value != password) return 'Password must be same';
    return '';
  }
}
