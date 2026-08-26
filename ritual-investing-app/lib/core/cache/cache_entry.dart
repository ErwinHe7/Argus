class CacheEntry<T> {
  const CacheEntry({required this.value, required this.committedAt});
  final T value;
  final DateTime committedAt;
  Duration age(DateTime now) => now.difference(committedAt);
}
