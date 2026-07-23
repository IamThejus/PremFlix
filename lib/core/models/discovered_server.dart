/// A Jellyfin server found on the local network during onboarding.
class DiscoveredServer {
  const DiscoveredServer({
    required this.name,
    required this.address,
    this.id,
  });

  /// Friendly server name (`ServerName` from the server), or its host
  /// when the server didn't provide one.
  final String name;

  /// Normalized base URL, no trailing slash (e.g. `http://192.168.1.20:8096`).
  final String address;

  /// Server id (`Id`), when known — the most reliable dedup key across
  /// discovery methods (the same server may answer both broadcast and
  /// mDNS with different-looking addresses).
  final String? id;

  /// Key used to collapse duplicates across discovery methods.
  String get dedupKey => id ?? address;

  /// `192.168.1.20:8096` — the address without its scheme, for display.
  String get displayAddress =>
      address.replaceFirst(RegExp(r'^https?://'), '');

  @override
  bool operator ==(Object other) =>
      other is DiscoveredServer && other.dedupKey == dedupKey;

  @override
  int get hashCode => dedupKey.hashCode;
}
