import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/image_url_builder.dart';
import '../models/media_item.dart';
import '../utils/responsive.dart';
import 'jellyfin_image.dart';

/// Horizontal rail of cast members: circular headshot, name, role.
/// Collapses when the item has no actor credits.
class CastRail extends ConsumerWidget {
  const CastRail({super.key, required this.people, this.maxCount = 15});

  final List<MediaPerson> people;
  final int maxCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actors = people
        .where((person) => person.type == 'Actor')
        .take(maxCount)
        .toList();
    if (actors.isEmpty) return const SizedBox.shrink();

    final images = ref.watch(imageUrlBuilderProvider);
    final inset = context.pageInset;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: inset, right: inset, bottom: 14),
            child: Text('Cast', style: theme.textTheme.headlineMedium),
          ),
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: inset),
              itemCount: actors.length,
              separatorBuilder: (context, index) => const SizedBox(width: 18),
              itemBuilder: (context, index) {
                final actor = actors[index];
                return SizedBox(
                  width: 84,
                  child: Column(
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 84,
                          height: 84,
                          child: JellyfinImage(
                            url: images.personImage(actor),
                            fallbackIcon: Icons.person_outline_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        actor.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall!
                            .copyWith(color: Colors.white),
                      ),
                      if (actor.role.isNotEmpty)
                        Text(
                          actor.role,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall!
                              .copyWith(fontSize: 11),
                        ),
                    ],
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
