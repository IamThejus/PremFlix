/// Display formatting helpers shared across screens.
library;

/// "2h 14m" / "48m" style runtime label.
String formatRuntime(Duration runtime) {
  final hours = runtime.inHours;
  final minutes = runtime.inMinutes.remainder(60);
  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

/// "45m left" style remaining-time label for resume UI.
String formatRemaining(Duration total, Duration position) {
  final remaining = total - position;
  if (remaining.isNegative) return '';
  return '${formatRuntime(remaining)} left';
}

/// One-decimal community rating ("7.8").
String formatRating(double rating) => rating.toStringAsFixed(1);

/// "1:23:45" / "23:45" player timestamp.
String formatTimestamp(Duration position) {
  final hours = position.inHours;
  final minutes = position.inMinutes.remainder(60);
  final seconds = position.inSeconds.remainder(60);
  String pad(int value) => value.toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${pad(minutes)}:${pad(seconds)}'
      : '$minutes:${pad(seconds)}';
}
