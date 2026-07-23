import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/discovered_server.dart';
import '../../../../core/services/server_discovery_service.dart';

/// Snapshot of the local-network scan.
class DiscoveryState {
  const DiscoveryState({required this.scanning, required this.servers});

  const DiscoveryState.initial() : scanning = true, servers = const [];

  /// True while the scan window is still open.
  final bool scanning;

  /// Servers found so far, in discovery order.
  final List<DiscoveredServer> servers;

  /// The scan finished and turned up nothing.
  bool get isEmptyResult => !scanning && servers.isEmpty;

  DiscoveryState copyWith({bool? scanning, List<DiscoveredServer>? servers}) =>
      DiscoveryState(
        scanning: scanning ?? this.scanning,
        servers: servers ?? this.servers,
      );
}

/// Runs a network scan on entry and streams discovered servers into
/// [DiscoveryState]. Auto-disposes, so leaving the onboarding screen
/// cancels the scan and releases its sockets.
class DiscoveryController extends Notifier<DiscoveryState> {
  StreamSubscription<DiscoveredServer>? _subscription;

  @override
  DiscoveryState build() {
    ref.onDispose(() => _subscription?.cancel());
    _start();
    return const DiscoveryState.initial();
  }

  void _start() {
    _subscription?.cancel();
    state = const DiscoveryState.initial();
    _subscription =
        ref.read(serverDiscoveryServiceProvider).discover().listen(
      (server) {
        state = state.copyWith(servers: [...state.servers, server]);
      },
      onDone: () {
        state = state.copyWith(scanning: false);
      },
    );
  }

  /// Re-runs the scan (the "Retry Search" action).
  void retry() => _start();
}

final discoveryControllerProvider =
    NotifierProvider.autoDispose<DiscoveryController, DiscoveryState>(
  DiscoveryController.new,
);
