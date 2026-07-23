import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/media_item.dart';
import '../../../../core/repositories/library_repository.dart';

/// Every Jellyfin collection (box set) on the server, for the Collections
/// grid. Reuses the cached [LibraryRepository.collections].
final collectionsGridProvider = FutureProvider<List<MediaItem>>(
  (ref) => ref.watch(libraryRepositoryProvider).collections(),
);
