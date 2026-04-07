class TimeUtils {
  TimeUtils._();

  static String formatExactDateTime(DateTime timestamp) {
    final local = timestamp.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }

  static String formatTimeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inDays}d ago';
  }

  static String formatTimeAgoShort(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inDays}d ago';
  }

  static String formatTimeAgoForSound(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);

    if (diff.inMinutes < 1) {
      return '${diff.inSeconds}s ago';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    }
    return '${diff.inHours}h ago';
  }
}
