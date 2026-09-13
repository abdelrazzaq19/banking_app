import 'dart:async';

import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/presentation/widget/app_text_field.dart';

/// The grab handle at the top of a sheet.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        margin: const EdgeInsets.only(bottom: Insets.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Insets.xxs),
          color: context.colors.mutedBorder,
        ),
      ),
    );
  }
}

/// A searchable list in a modal sheet, returning the item the user picked.
///
/// Returns the selected item, or `null` if the sheet was dismissed. Resolving
/// to a value is what keeps the caller's state in one place: the two hand-rolled
/// copies this replaces each mutated screen state from inside the sheet's
/// builder, and one of them gated selection behind a flag that was never set,
/// so no item could be chosen at all.
///
/// [matches] decides what the search box filters on; [itemBuilder] draws a row
/// and receives the active query so it can highlight what matched. The row does
/// not need its own tap handler — the sheet supplies one.
Future<T?> showPickerSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required bool Function(T item, String query) matches,
  required Widget Function(BuildContext context, T item, String query)
      itemBuilder,
  String searchHint = 'Search',
  double heightFactor = 0.7,
  Duration searchDebounce = const Duration(milliseconds: 180),
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: Alphas.scrim),
    shape: const RoundedRectangleBorder(borderRadius: Radii.sheetTop),
    builder: (sheetContext) => _PickerSheet<T>(
      title: title,
      items: items,
      matches: matches,
      itemBuilder: itemBuilder,
      searchHint: searchHint,
      heightFactor: heightFactor,
      searchDebounce: searchDebounce,
    ),
  );
}

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.items,
    required this.matches,
    required this.itemBuilder,
    required this.searchHint,
    required this.heightFactor,
    required this.searchDebounce,
  });

  final String title;
  final List<T> items;
  final bool Function(T item, String query) matches;
  final Widget Function(BuildContext context, T item, String query)
      itemBuilder;
  final String searchHint;
  final double heightFactor;
  final Duration searchDebounce;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  final TextEditingController _searchController = TextEditingController();
  late List<T> _visibleItems = List.of(widget.items);
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Debounced so a long list is not re-filtered on every keystroke.
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(widget.searchDebounce, () {
      if (!mounted) return;
      setState(() {
        _query = query;
        _visibleItems = query.isEmpty
            ? List.of(widget.items)
            : widget.items.where((item) => widget.matches(item, query)).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      height: MediaQuery.of(context).size.height * widget.heightFactor,
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: Radii.sheetTop,
      ),
      padding: EdgeInsets.only(
        left: Insets.md,
        right: Insets.md,
        top: Insets.md,
        // Lifts the sheet clear of the keyboard when the search box is focused.
        bottom: MediaQuery.of(context).viewInsets.bottom + Insets.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Insets.md),
          AppTextField(
            controller: _searchController,
            hintText: widget.searchHint,
            semanticLabel: '${widget.title} search',
            prefixIcon: Icons.search_rounded,
            textInputAction: TextInputAction.search,
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: Insets.md),
          Expanded(
            child: _visibleItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Insets.lg),
                      child: Text(
                        '"$_query" not found',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: colors.subtleText),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _visibleItems.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: Insets.xs),
                    itemBuilder: (context, index) {
                      final item = _visibleItems[index];
                      return Material(
                        color: Colors.transparent,
                        borderRadius: Radii.mdAll,
                        child: InkWell(
                          borderRadius: Radii.mdAll,
                          onTap: () => Navigator.of(context).pop(item),
                          child: widget.itemBuilder(context, item, _query),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
