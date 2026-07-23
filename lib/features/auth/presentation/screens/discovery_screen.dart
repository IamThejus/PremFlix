import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/discovered_server.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/router/route_args.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/accent_button.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/entrance_reveal.dart';
import '../../../../core/widgets/ghost_button.dart';
import '../../../../core/widgets/premflix_wordmark.dart';
import '../controllers/discovery_controller.dart';
import '../widgets/scanning_pulse.dart';
import '../widgets/server_card.dart';

/// First-run onboarding: scans the local network for Jellyfin servers
/// before asking for anything, then offers the found servers as cards.
///
/// It always yields to manual entry — "Use another server" / "Enter
/// Server Address Manually" open the credentials screen with an editable
/// address field, so remote and hand-typed servers keep working. Fully
/// D-pad operable: server cards autofocus and every action is focusable.
class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  void _connect(BuildContext context, DiscoveredServer server) {
    context.pushNamed(
      AppRoutes.login,
      extra: LoginArgs(serverUrl: server.address, serverName: server.name),
    );
  }

  void _manual(BuildContext context) {
    context.pushNamed(AppRoutes.login, extra: const LoginArgs());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(discoveryControllerProvider);

    return Scaffold(
      body: AuroraBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: context.pageInset,
              vertical: 48,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _body(context, ref, state),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, DiscoveryState state) {
    if (state.servers.isNotEmpty) {
      return _ResultsView(
        key: const ValueKey('results'),
        servers: state.servers,
        stillScanning: state.scanning,
        onConnect: (server) => _connect(context, server),
        onManual: () => _manual(context),
      );
    }
    if (state.isEmptyResult) {
      return _NoServersView(
        key: const ValueKey('empty'),
        onRetry: () => ref.read(discoveryControllerProvider.notifier).retry(),
        onManual: () => _manual(context),
      );
    }
    return const _ScanningView(key: ValueKey('scanning'));
  }
}

/// Loading state: PremFlix mark inside the radar pulse + status text.
class _ScanningView extends StatelessWidget {
  const _ScanningView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('scanning'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const ScanningPulse(
          size: 220,
          child: PremFlixWordmark(fontSize: 30),
        ),
        const SizedBox(height: 36),
        Text(
          'Searching for Jellyfin servers…',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Looking across your local network',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// One or more servers found. A single server gets a prominent Connect
/// button; multiple become a focusable pick-list.
class _ResultsView extends StatelessWidget {
  const _ResultsView({
    super.key,
    required this.servers,
    required this.stillScanning,
    required this.onConnect,
    required this.onManual,
  });

  final List<DiscoveredServer> servers;
  final bool stillScanning;
  final ValueChanged<DiscoveredServer> onConnect;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final single = servers.length == 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EntranceReveal(
          child: Center(child: PremFlixWordmark(fontSize: 30)),
        ),
        const SizedBox(height: 30),
        EntranceReveal(
          delay: const Duration(milliseconds: 60),
          child: Text(
            single ? 'Available Server' : 'Choose a server',
            style: theme.textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < servers.length; i++) ...[
          EntranceReveal(
            delay: Duration(milliseconds: 100 + i * 60),
            child: ServerCard(
              server: servers[i],
              autofocus: i == 0,
              onSelect: () => onConnect(servers[i]),
            ),
          ),
          if (i < servers.length - 1) const SizedBox(height: 12),
        ],
        if (single) ...[
          const SizedBox(height: 22),
          EntranceReveal(
            delay: const Duration(milliseconds: 180),
            child: AccentButton(
              label: 'Connect',
              icon: Icons.arrow_forward_rounded,
              onPressed: () => onConnect(servers.first),
            ),
          ),
        ],
        const SizedBox(height: 14),
        EntranceReveal(
          delay: const Duration(milliseconds: 240),
          child: GhostButton(
            label: 'Use another server',
            icon: Icons.edit_outlined,
            onPressed: onManual,
          ),
        ),
        if (stillScanning) ...[
          const SizedBox(height: 20),
          const _StillScanningHint(),
        ],
      ],
    );
  }
}

/// A subtle "still looking" hint shown when more servers may yet appear.
class _StillScanningHint extends StatelessWidget {
  const _StillScanningHint();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Still searching…',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Empty state: nothing found. Offers a retry and manual entry.
class _NoServersView extends StatelessWidget {
  const _NoServersView({
    super.key,
    required this.onRetry,
    required this.onManual,
  });

  final VoidCallback onRetry;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EntranceReveal(
          child: Center(child: PremFlixWordmark(fontSize: 30)),
        ),
        const SizedBox(height: 34),
        const EntranceReveal(
          delay: Duration(milliseconds: 60),
          child: Icon(
            Icons.wifi_find_outlined,
            size: 52,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 18),
        EntranceReveal(
          delay: const Duration(milliseconds: 100),
          child: Text(
            'No Jellyfin servers were found on your local network.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 30),
        EntranceReveal(
          delay: const Duration(milliseconds: 160),
          child: AccentButton(
            label: 'Retry Search',
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
          ),
        ),
        const SizedBox(height: 12),
        EntranceReveal(
          delay: const Duration(milliseconds: 220),
          child: GhostButton(
            label: 'Enter Server Address Manually',
            icon: Icons.keyboard_outlined,
            onPressed: onManual,
          ),
        ),
      ],
    );
  }
}
