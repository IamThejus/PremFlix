import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../theme/app_theme.dart';

/// Circular user avatar: the profile picture from Jellyfin when one is
/// set, otherwise the user's initial on an accent gradient.
///
/// The gradient fallback means every account looks intentional out of the
/// box — no gray placeholder person icon.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.session, this.size = 36});

  final AuthSession session;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageUrl = session.userImageUrl;
    final initial =
        session.userName.isEmpty ? '?' : session.userName[0].toUpperCase();

    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: context.accentGradient,
      ),
      child: Center(
        child: Text(
          initial,
          style: Theme.of(context).textTheme.labelLarge!.copyWith(
                fontSize: size * 0.44,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );

    return SizedBox(
      width: size,
      height: size,
      child: imageUrl == null
          ? fallback
          : ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (context, url) => fallback,
                errorWidget: (context, url, error) => fallback,
              ),
            ),
    );
  }
}
