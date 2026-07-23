import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multicast_dns/multicast_dns.dart';

import '../models/discovered_server.dart';

/// Discovers Jellyfin servers on the local network for onboarding.
///
/// Runs three methods concurrently, emitting each server as it is found
/// (deduped) so cards can pop into the UI live:
///
///  1. **UDP broadcast** on port 7359 — Jellyfin's own client auto-
///     discovery. A `"who is JellyfinServer?"` datagram to the broadcast
///     address; servers reply with JSON `{Name, Address, Id}`. The most
///     reliable method and the primary one.
///  2. **mDNS** for `_jellyfin._tcp.local` — resolved to host:port then
///     validated. Best-effort; silently skipped where multicast is
///     unavailable.
///  3. **Subnet scan** — a gated fallback that probes `/System/Info/Public`
///     across the local /24 on port 8096, started only if the faster
///     methods have found nothing after a short grace period (it is the
///     chattiest, so it stays a last resort).
///
/// The whole scan is bounded by [discover]'s timeout; all sockets and
/// probes are torn down when it elapses or the stream is cancelled.
class ServerDiscoveryService {
  static const int _jellyfinDiscoveryPort = 7359;
  static const String _broadcastMessage = 'who is JellyfinServer?';
  static const int _defaultHttpPort = 8096;
  static const Duration _scanGrace = Duration(milliseconds: 1800);
  static const Duration _probeTimeout = Duration(milliseconds: 700);

  /// Emits servers as they are discovered and closes when [timeout]
  /// elapses. Never emits the same server (by [DiscoveredServer.dedupKey])
  /// twice.
  Stream<DiscoveredServer> discover({
    Duration timeout = const Duration(seconds: 7),
  }) {
    final controller = StreamController<DiscoveredServer>();
    final seen = <String>{};
    final resources = _DiscoveryResources();
    var closed = false;

    void emit(DiscoveredServer server) {
      if (closed || controller.isClosed) return;
      if (seen.add(server.dedupKey)) controller.add(server);
    }

    Future<void> shutdown() async {
      if (closed) return;
      closed = true;
      await resources.dispose();
      if (!controller.isClosed) await controller.close();
    }

    // Fire the fast methods immediately.
    unawaited(_broadcast(emit, resources));
    unawaited(_mdns(emit, resources));

    // Subnet scan only if nothing surfaced during the grace window.
    final scanTimer = Timer(_scanGrace, () {
      if (!closed && seen.isEmpty) {
        unawaited(_scanSubnet(emit, resources));
      }
    });

    final deadline = Timer(timeout, shutdown);

    controller.onCancel = () {
      scanTimer.cancel();
      deadline.cancel();
      return shutdown();
    };

    return controller.stream;
  }

  // --- Method 1: Jellyfin UDP broadcast --------------------------------

  Future<void> _broadcast(
    void Function(DiscoveredServer) emit,
    _DiscoveryResources resources,
  ) async {
    try {
      final socket =
          await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      resources.sockets.add(socket);
      socket.broadcastEnabled = true;
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket.receive();
        if (datagram == null) return;
        final server = _parseBroadcastReply(datagram.data);
        if (server != null) emit(server);
      });

      final payload = utf8.encode(_broadcastMessage);
      // Global broadcast plus each interface's directed broadcast, since
      // some networks drop 255.255.255.255 but pass the directed form.
      final targets = <InternetAddress>{
        InternetAddress('255.255.255.255'),
        ...await _directedBroadcastAddresses(),
      };
      for (final target in targets) {
        socket.send(payload, target, _jellyfinDiscoveryPort);
      }
    } on Object {
      // Broadcast unsupported on this interface/platform — other methods
      // still run.
    }
  }

  DiscoveredServer? _parseBroadcastReply(List<int> data) {
    try {
      final json = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
      final address = json['Address'] as String?;
      if (address == null) return null;
      final normalized = _normalize(address);
      return DiscoveredServer(
        name: (json['Name'] as String?)?.trim().isNotEmpty ?? false
            ? json['Name'] as String
            : _hostOf(normalized),
        address: normalized,
        id: json['Id'] as String?,
      );
    } on Object {
      return null;
    }
  }

  Future<List<InternetAddress>> _directedBroadcastAddresses() async {
    final result = <InternetAddress>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length == 4) {
            result.add(InternetAddress('${parts[0]}.${parts[1]}.${parts[2]}.255'));
          }
        }
      }
    } on Object {
      // Best-effort.
    }
    return result;
  }

  // --- Method 2: mDNS ---------------------------------------------------

  Future<void> _mdns(
    void Function(DiscoveredServer) emit,
    _DiscoveryResources resources,
  ) async {
    MDnsClient? client;
    try {
      client = MDnsClient();
      resources.mdnsClients.add(client);
      await client.start();
      const service = '_jellyfin._tcp.local';

      await for (final ptr in client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(service),
      )) {
        if (resources.disposed) return;
        await for (final srv in client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
        )) {
          if (resources.disposed) return;
          await for (final ip in client.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
          )) {
            if (resources.disposed) return;
            final base = 'http://${ip.address.address}:${srv.port}';
            final server = await _probe(base, resources);
            if (server != null) emit(server);
          }
        }
      }
    } on Object {
      // mDNS frequently unavailable (no multicast lock, restrictive
      // networks) — that's fine, it's a secondary method.
    }
  }

  // --- Method 3: subnet scan -------------------------------------------

  Future<void> _scanSubnet(
    void Function(DiscoveredServer) emit,
    _DiscoveryResources resources,
  ) async {
    final prefixes = await _localPrefixes();
    for (final prefix in prefixes) {
      final hosts = [for (var i = 1; i <= 254; i++) '$prefix$i'];
      // Bounded concurrency so a /24 sweep stays quick and light.
      const batchSize = 24;
      for (var start = 0; start < hosts.length; start += batchSize) {
        if (resources.disposed) return;
        final batch = hosts.skip(start).take(batchSize);
        await Future.wait(
          batch.map((host) async {
            final server = await _probe(
              'http://$host:$_defaultHttpPort',
              resources,
            );
            if (server != null) emit(server);
          }),
        );
      }
    }
  }

  Future<List<String>> _localPrefixes() async {
    final prefixes = <String>{};
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length == 4) {
            prefixes.add('${parts[0]}.${parts[1]}.${parts[2]}.');
          }
        }
      }
    } on Object {
      // No usable interface — scan simply does nothing.
    }
    return prefixes.toList();
  }

  // --- Validation -------------------------------------------------------

  /// Confirms a candidate is a Jellyfin server via `/System/Info/Public`
  /// and reads its friendly name and id. Returns null for anything that
  /// isn't a reachable Jellyfin instance.
  Future<DiscoveredServer?> _probe(
    String base,
    _DiscoveryResources resources,
  ) async {
    if (resources.disposed) return null;
    final dio = Dio(
      BaseOptions(
        baseUrl: base,
        connectTimeout: _probeTimeout,
        receiveTimeout: _probeTimeout,
        headers: const {'Accept': 'application/json'},
      ),
    );
    try {
      final response =
          await dio.get<Map<String, dynamic>>('/System/Info/Public');
      final data = response.data;
      final id = data?['Id'] as String?;
      if (id == null) return null;
      final name = (data?['ServerName'] as String?)?.trim();
      return DiscoveredServer(
        name: name != null && name.isNotEmpty ? name : _hostOf(base),
        address: base,
        id: id,
      );
    } on Object {
      return null;
    } finally {
      dio.close(force: true);
    }
  }

  String _normalize(String url) {
    var out = url.trim();
    while (out.endsWith('/')) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }

  String _hostOf(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.host.isNotEmpty) return uri.host;
    return url;
  }
}

/// Tracks the sockets and clients a single discovery run opens, so the
/// timeout / cancellation can tear them all down.
class _DiscoveryResources {
  final List<RawDatagramSocket> sockets = [];
  final List<MDnsClient> mdnsClients = [];
  bool disposed = false;

  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    for (final socket in sockets) {
      socket.close();
    }
    for (final client in mdnsClients) {
      client.stop();
    }
  }
}

final serverDiscoveryServiceProvider =
    Provider<ServerDiscoveryService>((ref) => ServerDiscoveryService());
