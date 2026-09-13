import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/data/media/image_source.dart';
import 'package:newtronic_banking/data/media/profile_picture.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';
import 'package:newtronic_banking/state/session_store.dart';
import 'package:provider/provider.dart';

/// The profile avatar, with the means to change it.
///
/// [pickImage] is injectable so tests can supply bytes directly. The real
/// picker opens a platform file dialog, which a widget test cannot drive, and
/// a feature whose only path runs through an undriveable dialog is a feature
/// with no tests.
class ProfileAvatarEditor extends StatefulWidget {
  const ProfileAvatarEditor({
    super.key,
    required this.image,
    this.pickImage = pickImageFromFiles,
    this.size = 84,
  });

  final String image;
  final PickImageBytes pickImage;
  final double size;

  @override
  State<ProfileAvatarEditor> createState() => _ProfileAvatarEditorState();
}

class _ProfileAvatarEditorState extends State<ProfileAvatarEditor> {
  bool _isBusy = false;

  bool get _hasPicture => widget.image.isNotEmpty;

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _openOptions() async {
    if (_isBusy) return;

    final choice = await showModalBottomSheet<_AvatarAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(_hasPicture ? 'Change photo' : 'Choose a photo'),
              onTap: () => Navigator.pop(sheetContext, _AvatarAction.choose),
            ),
            if (_hasPicture)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Remove photo'),
                onTap: () => Navigator.pop(sheetContext, _AvatarAction.remove),
              ),
            const SizedBox(height: Insets.sm),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    switch (choice) {
      case _AvatarAction.choose:
        await _choosePicture();
      case _AvatarAction.remove:
        await _save('', onFailure: 'The photo could not be removed.');
    }
  }

  Future<void> _choosePicture() async {
    setState(() => _isBusy = true);
    try {
      final raw = await widget.pickImage();
      // Cancelling is a decision, not a failure — nothing is said about it.
      if (raw == null || !mounted) return;

      final (encoded, failure) = await ProfilePicture.prepare(raw);
      if (!mounted) return;

      if (failure != null) {
        _say(failure.message);
        return;
      }

      await _save(encoded!, onFailure: 'The photo could not be saved.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _save(String image, {required String onFailure}) async {
    final session = context.read<SessionStore>();
    final saved = await session.setProfileImage(image);
    if (!saved) _say(onFailure);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: _hasPicture ? 'Change your profile photo' : 'Add a profile photo',
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          ClipRRect(
            borderRadius: Radii.pillAll,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: ExcludeSemantics(
                child: RemoteImage(
                  url: widget.image,
                  size: widget.size,
                  fallback: (context) => ProfilePhotoFallback(size: widget.size),
                ),
              ),
            ),
          ),

          // Covers the avatar rather than sitting beside it, so the tap target
          // is the picture itself — which is what a person reaches for.
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: _openOptions),
            ),
          ),

          if (_isBusy)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.45),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            )
          else
            IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(Insets.xxs),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.headerBackground,
                  border: Border.all(color: colors.onHeader, width: 2),
                ),
                child: Icon(
                  Icons.photo_camera_rounded,
                  size: 14,
                  color: colors.onHeader,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _AvatarAction { choose, remove }
