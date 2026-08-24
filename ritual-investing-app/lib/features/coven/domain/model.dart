import 'package:flutter/foundation.dart';

@immutable
class CovenEntry {
  const CovenEntry({
    required this.name,
    required this.symbol,
    required this.category,
    required this.focus,
  });
  final String name;
  final String? symbol;
  final String category;
  final String focus;
}

@immutable
class CovenModel {
  CovenModel({required List<CovenEntry> entries})
    : entries = List.unmodifiable(entries);
  final List<CovenEntry> entries;
}
