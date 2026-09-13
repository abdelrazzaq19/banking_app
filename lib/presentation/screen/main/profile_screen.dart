import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/theme_controller.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/data/media/image_source.dart';
import 'package:newtronic_banking/data/utils/identity_rules.dart';
import 'package:newtronic_banking/presentation/screen/main/widgets/edit_field_sheet.dart';
import 'package:newtronic_banking/presentation/screen/main/widgets/profile_avatar_editor.dart';
import 'package:newtronic_banking/presentation/screen/auth/authentication_screen.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';
import 'package:newtronic_banking/state/account_store.dart';
import 'package:newtronic_banking/state/session_store.dart';
import 'package:provider/provider.dart';

/// The signed-in user's details, and the way out of the app.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.pickImage = pickImageFromFiles});
  static const routeName = '/profile';

  /// How a new profile picture is chosen. Injectable so tests can supply
  /// bytes without a platform file dialog.
  final PickImageBytes pickImage;

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      message: 'Sign out of Newtronic Banking?',
      confirmLabel: 'Sign out',
      cancelLabel: 'Stay',
    );
    if (!confirmed || !context.mounted) return;

    await context.read<SessionStore>().signOut();
    if (!context.mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      AuthenticationScreen.routeName,
      (route) => false,
    );
  }

  Future<void> _editName(BuildContext context, String current) async {
    final next = await showEditFieldSheet(
      context: context,
      title: 'Your name',
      label: 'Full Name',
      initialValue: current,
      validate: validateFullName,
      textCapitalization: TextCapitalization.words,
    );
    if (next == null || !context.mounted) return;

    await _apply(context, name: next);
  }

  Future<void> _editEmail(BuildContext context, String current) async {
    final next = await showEditFieldSheet(
      context: context,
      title: 'Your email',
      label: 'Email',
      initialValue: current,
      validate: validateEmail,
      keyboardType: TextInputType.emailAddress,
      // Blocks the space a soft keyboard likes to add after an autocompleted
      // address, which would fail the pattern for no visible reason.
      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
    );
    if (next == null || !context.mounted) return;

    await _apply(context, email: next);
  }

  /// Saves the change, and says so either way.
  ///
  /// The sheet already enforces the format rules, so what reaches here is a
  /// collision with another account or a storage failure — neither of which
  /// the field could have known about on its own.
  Future<void> _apply(
    BuildContext context, {
    String? name,
    String? email,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final failure = await context
        .read<SessionStore>()
        .updateProfile(name: name, email: email);

    messenger.showSnackBar(SnackBar(
      content: Text(failure?.message ?? 'Saved.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final session = context.watch<SessionStore>();
    final user = session.currentUser;
    final accounts = context.watch<AccountStore>();

    return Scaffold(
      backgroundColor: colors.headerBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.onHeader,
        title: Text(
          'Profile',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: colors.onHeader),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildIdentity(context, user?.name, user?.image),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: Radii.sheetTop,
                  color: colors.sheetBackground,
                ),
                child: user == null
                    ? const EmptyState(
                        icon: Icons.person_off_rounded,
                        title: 'Not signed in',
                        message: 'Sign in to see your profile.',
                      )
                    : ListView(
                        padding: const EdgeInsets.all(Insets.lg),
                        children: staggeredReveal([
                          const SectionHeader(
                            title: 'Account',
                            padding: EdgeInsets.only(bottom: Insets.xs),
                          ),
                          _InfoRow(
                            label: 'Name',
                            value: user.name,
                            onEdit: () => _editName(context, user.name),
                          ),
                          // Username is shown but not editable: it is how an
                          // account is found at sign-in, and changing it would
                          // strand anyone who signs in by username.
                          _InfoRow(label: 'Username', value: user.username),
                          _InfoRow(
                            label: 'Email',
                            value: user.email,
                            onEdit: () => _editEmail(context, user.email),
                          ),
                          _InfoRow(
                            label: 'Accounts',
                            value: '${accounts.accounts.length}',
                          ),
                          _InfoRow(
                            label: 'Total balance',
                            value: accounts.total.formattedWithSymbol,
                            emphasise: true,
                          ),
                          const SectionHeader(
                            title: 'Appearance',
                            padding: EdgeInsets.only(
                              top: Insets.xl,
                              bottom: Insets.xs,
                            ),
                          ),
                          const _ThemeModeSelector(),
                          const SizedBox(height: Insets.xxl),
                          AppButton(
                            label: 'Sign out',
                            icon: Icons.logout_rounded,
                            variant: AppButtonVariant.secondary,
                            onPressed: () => _signOut(context),
                          ),
                        ]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentity(BuildContext context, String? name, String? image) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.lg),
      child: Column(
        children: [
          // Only offered to someone signed in: there is no record to write a
          // picture to otherwise.
          if (image == null)
            ClipRRect(
              borderRadius: Radii.pillAll,
              child: const ProfilePhotoFallback(size: 84),
            )
          else
            ProfileAvatarEditor(image: image, pickImage: pickImage),
          const SizedBox(height: Insets.sm),
          Text(
            name ?? 'Guest',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: colors.onHeader),
          ),
        ],
      ),
    );
  }
}

/// System / Light / Dark, as a segmented control.
class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController?>();
    if (controller == null) return const SizedBox.shrink();

    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(
          value: ThemeMode.system,
          label: Text('System'),
          icon: Icon(Icons.brightness_auto_rounded),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          label: Text('Light'),
          icon: Icon(Icons.light_mode_rounded),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          label: Text('Dark'),
          icon: Icon(Icons.dark_mode_rounded),
        ),
      ],
      selected: {controller.mode},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => controller.setMode(selection.first),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.emphasise = false,
    this.onEdit,
  });

  final String label;
  final String value;
  final bool emphasise;

  /// When set, the row becomes a control: tappable, with a pencil to say so.
  /// A row that only reads back a figure stays plain text.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final row = _buildRow(context, textTheme);
    final edit = onEdit;
    if (edit == null) return row;

    return Semantics(
      button: true,
      // container, because the row's own text is excluded below: without it
      // this Semantics has no node of its own to carry the label, and a
      // screen reader announces the row as unlabelled.
      container: true,
      label: 'Change your ${label.toLowerCase()}, currently $value',
      child: InkWell(
        onTap: edit,
        borderRadius: Radii.smAll,
        child: ExcludeSemantics(child: row),
      ),
    );
  }

  Widget _buildRow(BuildContext context, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium
                  ?.copyWith(color: context.colors.subtleText),
            ),
          ),
          const SizedBox(width: Insets.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: emphasise ? textTheme.titleMedium : textTheme.titleSmall,
            ),
          ),
          // Says the row is a control. Without it an editable row and a
          // read-only one look identical, and the only way to find out which
          // is which is to tap them.
          if (onEdit != null) ...[
            const SizedBox(width: Insets.xs),
            Icon(
              Icons.edit_outlined,
              size: 16,
              color: context.colors.subtleText,
            ),
          ],
        ],
      ),
    );
  }
}
