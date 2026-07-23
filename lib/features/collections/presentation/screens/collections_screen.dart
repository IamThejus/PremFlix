import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/entrance_reveal.dart';
import '../../../../core/widgets/media_card.dart';
import '../../../../core/widgets/shimmer.dart';
import '../../../shell/presentation/nav_metrics.dart';
import '../controllers/collections_providers.dart';

/// The Collections page: a responsive grid of large collection cards.
///
/// Selecting a collection opens its dedicated page — a box set routes to
/// the movie-details chrome, which already renders the collection's
/// backdrop and an "In This Collection" rail — so no bespoke detail
/// screen is duplicated here.
class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  int _columns(BuildContext context) => switch (context.screenSize) {
        ScreenSize.compact => 3,
        ScreenSize.medium => 4,
        ScreenSize.expanded => 5,
        ScreenSize.large => 6,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(collectionsGridProvider);
    final inset = context.pageInset;
    final topInset = premFlixContentTopInset(context);

    const spacing = 18.0;
    final columns = _columns(context);
    final available =
        MediaQuery.sizeOf(context).width - inset * 2 - spacing * (columns - 1);
    final cellWidth = available / columns;
    // MediaCard geometry: 2:3 poster + ~52px of title/subtitle.
    final cellHeight = cellWidth * 3 / 2 + 52;

    final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      crossAxisSpacing: spacing,
      mainAxisSpacing: 26,
      childAspectRatio: cellWidth / cellHeight,
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: topInset + 8)),
        SliverPadding(
          padding: EdgeInsets.only(left: inset, right: inset, bottom: 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Collections',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ),
        async.when(
          skipLoadingOnRefresh: true,
          loading: () => SliverPadding(
            padding: EdgeInsets.fromLTRB(inset, 8, inset, 48),
            sliver: SliverGrid.builder(
              gridDelegate: gridDelegate,
              itemCount: columns * 3,
              itemBuilder: (context, index) => Shimmer(
                child: MediaCardSkeleton(width: cellWidth),
              ),
            ),
          ),
          error: (error, stackTrace) => _messageSliver(
            context,
            icon: Icons.cloud_off_rounded,
            text: "Couldn't load collections.",
          ),
          data: (collections) {
            if (collections.isEmpty) {
              return _messageSliver(
                context,
                icon: Icons.collections_bookmark_outlined,
                text: 'No collections on this server yet.',
              );
            }
            return SliverPadding(
              padding: EdgeInsets.fromLTRB(inset, 8, inset, 48),
              sliver: SliverGrid.builder(
                gridDelegate: gridDelegate,
                itemCount: collections.length,
                itemBuilder: (context, index) {
                  final item = collections[index];
                  return EntranceReveal(
                    delay: Duration(milliseconds: 30 * (index % columns)),
                    child: MediaCard(
                      item: item,
                      width: cellWidth,
                      heroContext: 'collection',
                      onTap: () => openMediaDetails(
                        context,
                        item,
                        heroTag: 'poster-collection-${item.id}',
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _messageSliver(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.textTertiary),
            const SizedBox(height: 14),
            Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
