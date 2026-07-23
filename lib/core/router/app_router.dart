import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/discovery_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/collections/presentation/screens/collections_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/movies/presentation/screens/movie_details_screen.dart';
import '../../features/movies/presentation/screens/movies_screen.dart';
import '../../features/player/presentation/screens/player_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/series/presentation/screens/series_details_screen.dart';
import '../../features/series/presentation/screens/tv_shows_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/shell/presentation/premflix_shell.dart';
import '../services/session_controller.dart';
import 'app_transitions.dart';
import 'route_args.dart';

/// Central route table.
///
/// Paths and names live here as constants so navigation calls are typo-safe
/// (`context.goNamed(AppRoutes.home)`) and deep-link paths have a single
/// source of truth.
abstract final class AppRoutes {
  static const String splash = 'splash';
  static const String splashPath = '/';

  static const String discovery = 'discovery';
  static const String discoveryPath = '/discovery';

  static const String login = 'login';
  static const String loginPath = '/login';

  static const String home = 'home';
  static const String homePath = '/home';

  static const String movies = 'movies';
  static const String moviesPath = '/movies';

  static const String tvShows = 'tv-shows';
  static const String tvShowsPath = '/tv';

  static const String collections = 'collections';
  static const String collectionsPath = '/collections';

  static const String movieDetails = 'movie-details';
  static const String movieDetailsPath = '/movies/:id';

  static const String seriesDetails = 'series-details';
  static const String seriesDetailsPath = '/series/:id';

  static const String player = 'player';
  static const String playerPath = '/player/:id';

  static const String search = 'search';
  static const String searchPath = '/search';

  static const String settings = 'settings';
  static const String settingsPath = '/settings';
}

/// The app-wide [GoRouter], guarded by session state.
///
/// The router itself is built once; auth changes flow through
/// [refreshListenable] instead of rebuilding the router (a rebuild would
/// discard the entire navigation stack). Redirect rules:
///
///  * session restoring  → stay on splash (boot ident plays)
///  * signed out         → anywhere ➜ /login
///  * signed in          → splash & login ➜ /home; everything else allowed
final appRouterProvider = Provider<GoRouter>((ref) {
  // Bridges Riverpod → Listenable so go_router re-evaluates redirects
  // whenever the session changes (sign-in, sign-out, remote revocation).
  final refresh = ValueNotifier(0);
  ref
    ..listen(sessionControllerProvider, (_, _) => refresh.value++)
    ..onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.splashPath,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final location = state.matchedLocation;

      // Still restoring credentials: hold on the splash screen.
      if (session.isLoading) {
        return location == AppRoutes.splashPath ? null : AppRoutes.splashPath;
      }

      final signedIn = session.value != null;

      if (!signedIn) {
        // Signed out → onboarding. Discovery is the entry point; login is
        // reachable from it (server chosen, or manual entry), so both are
        // allowed to stay put.
        final onOnboarding = location == AppRoutes.discoveryPath ||
            location == AppRoutes.loginPath;
        return onOnboarding ? null : AppRoutes.discoveryPath;
      }
      final onEntryScreen = location == AppRoutes.splashPath ||
          location == AppRoutes.discoveryPath ||
          location == AppRoutes.loginPath;
      if (onEntryScreen) return AppRoutes.homePath;
      return null;
    },
    routes: [
      GoRoute(
        name: AppRoutes.splash,
        path: AppRoutes.splashPath,
        pageBuilder: (context, state) => AppTransitions.fade(
          key: state.pageKey,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        name: AppRoutes.discovery,
        path: AppRoutes.discoveryPath,
        pageBuilder: (context, state) => AppTransitions.fade(
          key: state.pageKey,
          child: const DiscoveryScreen(),
        ),
      ),
      GoRoute(
        name: AppRoutes.login,
        path: AppRoutes.loginPath,
        pageBuilder: (context, state) => AppTransitions.slideUp(
          key: state.pageKey,
          child: LoginScreen(args: LoginArgs.from(state.extra)),
        ),
      ),
      // The five primary tabs live in a persistent shell (indexed stack),
      // so each keeps its own navigator and scroll position. Detail,
      // player, and settings routes are siblings of the shell → they use
      // the root navigator and cover the navigation bar full-screen.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            PremFlixShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRoutes.home,
                path: AppRoutes.homePath,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRoutes.movies,
                path: AppRoutes.moviesPath,
                builder: (context, state) => const MoviesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRoutes.tvShows,
                path: AppRoutes.tvShowsPath,
                builder: (context, state) => const TvShowsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRoutes.collections,
                path: AppRoutes.collectionsPath,
                builder: (context, state) => const CollectionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRoutes.search,
                path: AppRoutes.searchPath,
                builder: (context, state) =>
                    const SearchScreen(embedded: true),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        name: AppRoutes.movieDetails,
        path: AppRoutes.movieDetailsPath,
        pageBuilder: (context, state) => AppTransitions.cinematic(
          key: state.pageKey,
          child: MovieDetailsScreen(
            itemId: state.pathParameters['id']!,
            args: MediaDetailsArgs.from(state.extra),
          ),
        ),
      ),
      GoRoute(
        name: AppRoutes.seriesDetails,
        path: AppRoutes.seriesDetailsPath,
        pageBuilder: (context, state) => AppTransitions.cinematic(
          key: state.pageKey,
          child: SeriesDetailsScreen(
            itemId: state.pathParameters['id']!,
            args: MediaDetailsArgs.from(state.extra),
          ),
        ),
      ),
      GoRoute(
        name: AppRoutes.player,
        path: AppRoutes.playerPath,
        pageBuilder: (context, state) => AppTransitions.slideUp(
          key: state.pageKey,
          child: PlayerScreen(
            itemId: state.pathParameters['id']!,
            args: PlayerArgs.from(state.extra),
          ),
        ),
      ),
      GoRoute(
        name: AppRoutes.settings,
        path: AppRoutes.settingsPath,
        pageBuilder: (context, state) => AppTransitions.slideUp(
          key: state.pageKey,
          child: const SettingsScreen(),
        ),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
