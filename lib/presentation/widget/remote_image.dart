import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';

/// A square remote image with one fallback covering every case it can't show.
///
/// An empty [url] never reaches the network. `CachedNetworkImage` treats '' as
/// a URL to fetch: it opens its cache manager, which asks `path_provider` for
/// a directory, all for a request that cannot succeed. Seed data and new
/// payees routinely have no logo, so that is the common path, not the rare one.
///
/// Loading and failure share the [fallback] deliberately. Showing a blank box
/// first and an icon a moment later reads as a glitch; one stable placeholder
/// that resolves into the real image does not.
class RemoteImage extends StatelessWidget {
  const RemoteImage({
    super.key,
    required this.url,
    required this.size,
    required this.fallback,
  });

  final String url;
  final double size;
  final WidgetBuilder fallback;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return fallback(context);

    return CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: (context, _) => fallback(context),
      errorWidget: (context, _, _) => fallback(context),
    );
  }
}

/// Stands in for a bank logo that isn't available.
class BankLogoFallback extends StatelessWidget {
  const BankLogoFallback({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: context.colors.mutedFill,
      child: Icon(Icons.account_balance_rounded, size: size * 0.45),
    );
  }
}

/// Stands in for a payee's picture, using the first letter of their name.
///
/// A letter identifies the row where a generic icon would leave every entry in
/// a list looking the same.
class InitialFallback extends StatelessWidget {
  const InitialFallback({super.key, required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: context.colors.mutedBorder,
      child: Text(
        trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

/// The bundled photo shown when a user has no picture of their own.
class ProfilePhotoFallback extends StatelessWidget {
  const ProfilePhotoFallback({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'lib/assets/images/profile.jpg',
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
  }
}
