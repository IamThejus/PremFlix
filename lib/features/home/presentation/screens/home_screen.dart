import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/media_item.dart';
import '../../../../core/router/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../shell/presentation/nav_metrics.dart';
import '../controllers/home_providers.dart';
import '../widgets/hero_banner.dart';
import '../widgets/media_row.dart';

/// The Home tab: a full-bleed hero banner followed by the curated rows.
///
/// The navigation bar and account menu live in the surrounding shell, so
/// this screen is purely the scrolling content. The hero runs edge-to-
/// edge behind the floating top nav; pull-to-refresh forces every row
/// past its cache TTL.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final heroHeight = context.isCompact
        ? (viewportHeight * 0.58).clamp(360.0, 560.0)
        : (viewportHeight * 0.72).clamp(420.0, 760.0);

    void openDetails(MediaItem item, [String? heroTag]) =>
        openMediaDetails(context, item, heroTag: heroTag);

    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      backgroundColor: AppColors.card,
      edgeOffset: premFlixContentTopInset(context),
      onRefresh: () => ref.read(homeRefresherProvider)(),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: HeroBanner(
              height: heroHeight,
              onPlay: (item) => openPlayer(context, item),
              onInfo: openDetails,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          for (final kind in HomeRowKind.values)
            SliverToBoxAdapter(
              child: MediaRow(
                kind: kind,
                onItemTap: (item, heroTag) => openDetails(item, heroTag),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }
}
