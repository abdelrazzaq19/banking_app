import 'package:flutter/material.dart';
import 'package:newtronic_banking/common/constants.dart';
import 'package:newtronic_banking/data/repository/repository.dart';
import 'package:newtronic_banking/presentation/screen/main/home_screen.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/motion.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/presentation/widget/components.dart';
import 'package:newtronic_banking/presentation/widget/theme_toggle_button.dart';
import 'package:newtronic_banking/styles/typography.dart';

class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({super.key});
  static const routeName = '/authentication';

  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  static const _pageWelcome = 0;
  static const _pageLogIn = 1;
  static const _pageSignUp = 2;

  final PageController pageController = PageController();
  final List<TextEditingController> logInControllers = List.generate(
      logInTextFieldProperties.length, (_) => TextEditingController());
  final List<TextEditingController> signUpControllers = List.generate(
      signUpTextFieldProperties.length, (_) => TextEditingController());

  List<String> logInErrorTexts =
      List.generate(logInTextFieldProperties.length, (_) => '');
  List<String> signUpErrorTexts =
      List.generate(signUpTextFieldProperties.length, (_) => '');
  int pageIndex = _pageWelcome;
  bool isPasswordObscure = true;

  /// Whether every field on the currently visible form has been filled in.
  ///
  /// Drives the button's enabled colouring. The welcome page has no fields, so
  /// it is always considered complete.
  bool get isCurrentFormComplete {
    switch (pageIndex) {
      case _pageLogIn:
        return logInControllers.every((field) => field.text.isNotEmpty);
      case _pageSignUp:
        return signUpControllers.every((field) => field.text.isNotEmpty);
      default:
        return true;
    }
  }

  @override
  void dispose() {
    pageController.dispose();
    for (final controller in logInControllers) {
      controller.dispose();
    }
    for (final controller in signUpControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void goToPage(int index) => pageController.animateToPage(
        index,
        duration: Motion.medium,
        curve: Motion.move,
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || pageIndex == _pageWelcome) return;
        goToPage(pageIndex - 1);
      },
      child: Scaffold(
        backgroundColor: context.scheme.surface,
        body: SafeArea(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.xl,
              vertical: Insets.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Visibility(
                  visible: MediaQuery.of(context).viewInsets.bottom == 0,
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerRight,
                        child: ThemeToggleButton(),
                      ),
                      Image.asset('lib/assets/images/logo.png'),
                      Visibility(
                        visible: pageIndex != _pageWelcome,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Column(
                            children: [
                              customText(
                                textValue: pageIndex == _pageLogIn
                                    ? 'Log in Now'
                                    : 'Sign Up Now',
                                textStyle: headline2.copyWith(color: context.scheme.onSurface),
                                textAlign: TextAlign.center,
                              ),
                              customSpaceVertical(8),
                              customText(
                                textValue: pageIndex == _pageLogIn
                                    ? 'Please log in to continue using app'
                                    : 'Please fill details to create an account',
                                textStyle: bodyText2.copyWith(color: context.colors.subtleText),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: pageController,
                    onPageChanged: (newPageIndex) =>
                        setState(() => pageIndex = newPageIndex),
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 3,
                    itemBuilder: (context, index) => Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildContent(index),
                        _buildButton(context),
                      ],
                    ),
                  ),
                ),
                Visibility(
                  visible: MediaQuery.of(context).viewInsets.bottom == 0,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      height: 10,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        separatorBuilder: (context, index) =>
                            customSpaceHorizontal(8),
                        shrinkWrap: true,
                        itemCount: 3,
                        itemBuilder: (context, index) => Container(
                          width: 30,
                          height: 10,
                          decoration: BoxDecoration(
                            color: pageIndex == index
                                ? context.scheme.primary
                                : context.colors.mutedBorder,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Padding _buildContent(int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: index == _pageWelcome
            ? [
                Image.asset('lib/assets/images/welcome.png'),
                customSpaceVertical(16),
                customText(
                  textValue: 'Welcome',
                  textStyle: headline2.copyWith(color: context.scheme.onSurface),
                  textAlign: TextAlign.center,
                ),
                customSpaceVertical(16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: customText(
                    textValue:
                        'Create an account and get access to all cool stuff',
                    textStyle: bodyText2.copyWith(color: context.colors.subtleText),
                    textAlign: TextAlign.center,
                  ),
                ),
              ]
            : [
                Visibility(
                  visible: pageIndex == _pageSignUp,
                  child: ListView.separated(
                    separatorBuilder: (context, index) =>
                        customSpaceVertical(16),
                    shrinkWrap: true,
                    itemCount: signUpTextFieldProperties.length,
                    itemBuilder: (context, field) {
                      final isPasswordField = field == 3 || field == 4;
                      return customTextField(
                        context,
                        controller: signUpControllers[field],
                        keyboardType: signUpTextFieldProperties[field]['type']
                            as TextInputType,
                        inputFormatters: signUpTextFieldProperties[field]
                            ['inputFormatters'],
                        prefixIcon:
                            signUpTextFieldProperties[field]['icon'] as IconData,
                        hintText: signUpTextFieldProperties[field]['hintText']
                            as String,
                        errorText: signUpErrorTexts[field],
                        onChanged: (_) => setState(() {}),
                        obscureText: isPasswordField && isPasswordObscure,
                        suffixIcon: isPasswordField
                            ? _buildPasswordToggle(context)
                            : null,
                      );
                    },
                  ),
                ),
                Visibility(
                  visible: pageIndex == _pageLogIn,
                  child: ListView.separated(
                    separatorBuilder: (context, index) =>
                        customSpaceVertical(16),
                    shrinkWrap: true,
                    itemCount: logInTextFieldProperties.length,
                    itemBuilder: (context, field) {
                      final isPasswordField = field == 1;
                      return customTextField(
                        context,
                        controller: logInControllers[field],
                        keyboardType: logInTextFieldProperties[field]['type']
                            as TextInputType,
                        inputFormatters: logInTextFieldProperties[field]
                            ['inputFormatters'],
                        prefixIcon:
                            logInTextFieldProperties[field]['icon'] as IconData,
                        hintText:
                            logInTextFieldProperties[field]['hintText'] as String,
                        errorText: logInErrorTexts[field],
                        onChanged: (_) => setState(() {}),
                        obscureText: isPasswordField && isPasswordObscure,
                        suffixIcon: isPasswordField
                            ? _buildPasswordToggle(context)
                            : null,
                      );
                    },
                  ),
                ),
                Visibility(
                  visible: pageIndex == _pageLogIn,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: () {},
                        child: customText(
                          textValue: 'Forgot Password?',
                          textStyle: subHeadline5.copyWith(color: context.colors.accent),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
      ),
    );
  }

  Widget _buildPasswordToggle(BuildContext context) {
    return IconButton(
      onPressed: () => setState(() => isPasswordObscure = !isPasswordObscure),
      tooltip: isPasswordObscure ? 'Show password' : 'Hide password',
      icon: Icon(
        isPasswordObscure
            ? Icons.visibility_off_rounded
            : Icons.visibility_rounded,
        color: context.colors.subtleText,
      ),
    );
  }

  Column _buildButton(BuildContext context) {
    final isEnabledLook = pageIndex == _pageWelcome || isCurrentFormComplete;
    return Column(
      children: [
        customButton(
          buttonOnTap: () {
            switch (pageIndex) {
              case _pageWelcome:
                goToPage(_pageSignUp);
                break;
              case _pageLogIn:
                loginFunction();
                break;
              case _pageSignUp:
                signupFunction();
                break;
            }
          },
          buttonText: pageIndex == _pageWelcome
              ? 'Get Started'
              : pageIndex == _pageLogIn
                  ? 'Log in'
                  : 'Sign Up',
          buttonFirstGradientColor: isEnabledLook
              ? context.scheme.primary
              : context.colors.mutedBorder,
          buttonSecondGradientColor: isEnabledLook
              ? context.colors.accent
              : context.colors.mutedBorder,
          textColor: isEnabledLook
              ? context.scheme.onPrimary
              : context.colors.subtleText,
          buttonWidth: MediaQuery.of(context).size.width * 0.65,
        ),
        customSpaceVertical(16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            customText(
              textValue: pageIndex == _pageLogIn
                  ? 'Don\'t have an account?'
                  : 'Already have an account?',
              textStyle: bodyText2.copyWith(color: context.colors.subtleText),
            ),
            customSpaceHorizontal(4),
            InkWell(
              onTap: () => goToPage(
                  pageIndex == _pageLogIn ? _pageSignUp : _pageLogIn),
              child: customText(
                textValue: pageIndex == _pageLogIn ? 'Sign Up' : 'Log in',
                textStyle: subHeadline5.copyWith(color: context.colors.accent),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> loginFunction() async {
    logInValidation();
    if (!logInErrorTexts.every((message) => message.isEmpty)) return;

    showLoadingDialog(context);
    try {
      final user = await Repository().loginUser(
        emailOrUsername: logInControllers[0].text,
        password: logInControllers[1].text,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (user != null) {
        showSuccessDialog(
          context,
          message: 'Login Success',
          onAction: () => Navigator.pushReplacementNamed(
            context,
            HomeScreen.routeName,
            arguments: user.id,
          ),
        );
      } else {
        showErrorDialog(context, message: 'Account not found');
      }
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      showErrorDialog(context, message: error.toString());
    }
  }

  void signupFunction() {
    signUpValidation();
    if (!signUpErrorTexts.every((message) => message.isEmpty)) return;

    customDialogWithButton(
      context,
      dialogTextValue: 'Are you sure want to create an account?',
      dialogAction: () {
        Navigator.pop(context);
        showSuccessDialog(
          context,
          message: 'Register Success',
          onAction: () {
            for (final controller in signUpControllers) {
              controller.clear();
            }
            setState(() => signUpErrorTexts =
                List.generate(signUpTextFieldProperties.length, (_) => ''));
            goToPage(_pageLogIn);
          },
        );
      },
    );
  }

  void logInValidation() {
    setState(() {
      logInErrorTexts[0] = logInControllers[0].text.isEmpty
          ? 'Email or Username is required'
          : '';
      logInErrorTexts[1] =
          logInControllers[1].text.isEmpty ? 'Password is required' : '';
    });
  }

  void signUpValidation() {
    setState(() {
      signUpErrorTexts[0] = _validateFullName(signUpControllers[0].text);
      signUpErrorTexts[1] = _validateUsername(signUpControllers[1].text);
      signUpErrorTexts[2] = _validateEmail(signUpControllers[2].text);
      signUpErrorTexts[3] = _validatePassword(signUpControllers[3].text);
      signUpErrorTexts[4] = _validateConfirmPassword(
        signUpControllers[4].text,
        signUpControllers[3].text,
      );
    });
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

  /// Each rule is checked separately so the user is told exactly what is
  /// missing. The old single expression mixed `&&` and `||` without brackets,
  /// so a password of `aa1aaaaaa` passed while `Passw0rd!` could fail.
  String _validatePassword(String value) {
    if (value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password needs an uppercase letter';
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password needs a lowercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) return 'Password needs a number';
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password needs a symbol';
    }
    return '';
  }

  String _validateConfirmPassword(String value, String password) {
    if (value.isEmpty) return 'Confirm Password is required';
    if (value != password) return 'Password must be same';
    return '';
  }
}
