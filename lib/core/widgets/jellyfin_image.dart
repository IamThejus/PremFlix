import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Artwork loader used by every card and banner.
///
/// Wraps [CachedNetworkImage] with the PremFlix loading treatment: a
/// card-colored placeholder that fades into the artwork, and a quiet
/// icon fallback when the item has no image or the load fails ([url] is
/// nullable so callers don't branch). `memCacheWidth` bounds the decoded
/// bitmap, keeping memory flat in long poster rows.
class JellyfinImage extends StatelessWidget {
  const JellyfinImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.fallbackIcon = Icons.movie_outlined,
  });

  final String? url;
  final BoxFit fit;

  /// Max decoded width in physical pixels; pass roughly the layout width
  /// times the device pixel ratio.
  final int? memCacheWidth;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: AppColors.card,
      child: Center(
        child: Icon(fallbackIcon, color: AppColors.textTertiary, size: 32),
      ),
    );

    final imageUrl = url;
    if (imageUrl == null) return fallback;

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      memCacheWidth: memCacheWidth,
      fadeInDuration: const Duration(milliseconds: 250),
      fadeOutDuration: const Duration(milliseconds: 150),
      placeholder: (context, url) => const ColoredBox(color: AppColors.card),
      errorWidget: (context, url, error) => fallback,
    );
  }
}
