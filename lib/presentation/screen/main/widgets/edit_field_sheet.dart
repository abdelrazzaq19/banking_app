import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';

/// Edits one value, refusing to hand back one that breaks [validate].
///
/// Resolves to the new value, or null if the user backed out. A sheet rather
/// than a screen: changing a name is a single field, and pushing a route for
/// it would lose the profile behind a transition for no gain.
Future<String?> showEditFieldSheet({
  required BuildContext context,
  required String title,
  required String label,
  required String initialValue,
  required String? Function(String) validate,
  TextInputType keyboardType = TextInputType.text,
  TextCapitalization textCapitalization = TextCapitalization.none,
  List<TextInputFormatter>? inputFormatters,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      // Lifts the field clear of the keyboard, which on a phone would
      // otherwise cover the thing being edited.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _EditFieldSheet(
        title: title,
        label: label,
        initialValue: initialValue,
        validate: validate,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
      ),
    ),
  );
}

class _EditFieldSheet extends StatefulWidget {
  const _EditFieldSheet({
    required this.title,
    required this.label,
    required this.initialValue,
    required this.validate,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
  });

  final String title;
  final String label;
  final String initialValue;
  final String? Function(String) validate;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<_EditFieldSheet> createState() => _EditFieldSheetState();
}

class _EditFieldSheetState extends State<_EditFieldSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  /// Empty until the user types, so a sheet does not open already scolding
  /// them about a value they have not touched.
  String _error = '';
  bool _hasEdited = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _value => _controller.text.trim();

  bool get _canSave =>
      widget.validate(_value) == null && _value != widget.initialValue.trim();

  void _onChanged(String raw) {
    setState(() {
      _hasEdited = true;
      _error = widget.validate(raw.trim()) ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        0,
        Insets.lg,
        Insets.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Insets.md),
          AppTextField(
            controller: _controller,
            hintText: widget.label,
            semanticLabel: widget.label,
            autofocus: true,
            keyboardType: widget.keyboardType,
            textCapitalization: widget.textCapitalization,
            inputFormatters: widget.inputFormatters,
            errorText: _hasEdited ? _error : '',
            onChanged: _onChanged,
            onSubmitted: (_) {
              if (_canSave) Navigator.pop(context, _value);
            },
          ),
          const SizedBox(height: Insets.lg),
          AppButton(
            label: 'Save',
            // Disabled rather than failing on tap: a rule the field already
            // knows about should not need a round trip to report.
            onPressed: _canSave ? () => Navigator.pop(context, _value) : null,
          ),
          const SizedBox(height: Insets.xs),
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
