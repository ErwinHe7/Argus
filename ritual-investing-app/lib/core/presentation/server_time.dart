abstract final class ServerTime {
  static String timestamp(DateTime value) {
    final utc = value.toUtc();
    String twoDigits(int part) => part.toString().padLeft(2, '0');
    return '${utc.year}-${twoDigits(utc.month)}-${twoDigits(utc.day)} '
        '${twoDigits(utc.hour)}:${twoDigits(utc.minute)} UTC';
  }
}
