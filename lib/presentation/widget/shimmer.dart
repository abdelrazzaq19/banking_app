import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/presentation/widget/components.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton colours taken from the theme, so placeholders are visible in dark
/// mode instead of being near-white blocks on a dark surface.
({Color base, Color highlight}) _shimmerColors(BuildContext context) {
  final colors = context.colors;
  return context.isDark
      ? (base: colors.mutedFill, highlight: colors.mutedBorder)
      : (base: colors.mutedFill, highlight: context.scheme.surface);
}

Shimmer _shimmerBox(
  BuildContext context, {
  required double width,
  double? height,
  required BoxDecoration decoration,
}) {
  final palette = _shimmerColors(context);
  return Shimmer.fromColors(
    baseColor: palette.base,
    highlightColor: palette.highlight,
    child: Container(
      width: width,
      height: height,
      decoration: decoration.copyWith(color: palette.base),
    ),
  );
}

Container shimmerHeader(BuildContext context) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: Insets.lg),
    height: 60,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        shimmerCircle(context),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            shimmerText(context, shimmerWidth: 80, shimmerHeight: 16),
            customSpaceVertical(Insets.xs),
            shimmerText(context, shimmerWidth: 140, shimmerHeight: 16),
          ],
        ),
        shimmerCircle(context),
      ],
    ),
  );
}

Container shimmerCard(BuildContext context) {
  return Container(
    height: 240,
    margin: const EdgeInsets.only(top: Insets.xs),
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
      scrollDirection: Axis.horizontal,
      separatorBuilder: (_, _) => customSpaceHorizontal(Insets.md),
      shrinkWrap: true,
      itemCount: 5,
      itemBuilder: (_, _) => _shimmerBox(
        context,
        width: 240,
        decoration: BoxDecoration(borderRadius: Radii.mdAll),
      ),
    ),
  );
}

Container shimmerClip(BuildContext context) {
  return Container(
    height: 48,
    margin: const EdgeInsets.only(top: Insets.xs),
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
      scrollDirection: Axis.horizontal,
      separatorBuilder: (_, _) => customSpaceHorizontal(Insets.xs),
      shrinkWrap: true,
      itemCount: 5,
      itemBuilder: (_, _) => _shimmerBox(
        context,
        width: 120,
        decoration: BoxDecoration(borderRadius: Radii.pillAll),
      ),
    ),
  );
}

Container shimmerTile(BuildContext context) {
  return Container(
    margin: const EdgeInsets.only(top: Insets.xs),
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
      scrollDirection: Axis.vertical,
      separatorBuilder: (_, _) => customSpaceVertical(Insets.xs),
      shrinkWrap: true,
      itemCount: 3,
      itemBuilder: (_, _) => _shimmerBox(
        context,
        width: 120,
        height: 60,
        decoration: BoxDecoration(borderRadius: Radii.mdAll),
      ),
    ),
  );
}

Shimmer shimmerText(
  BuildContext context, {
  required double shimmerWidth,
  required double shimmerHeight,
}) {
  return _shimmerBox(
    context,
    width: shimmerWidth,
    height: shimmerHeight,
    decoration: BoxDecoration(borderRadius: Radii.mdAll),
  );
}

Shimmer shimmerCircle(BuildContext context) {
  return _shimmerBox(
    context,
    width: 44,
    height: 44,
    decoration: const BoxDecoration(shape: BoxShape.circle),
  );
}
