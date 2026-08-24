import 'package:flutter/foundation.dart';

@immutable
class CovenEntry {
  const CovenEntry({
    required this.name,
    required this.symbol,
    required this.category,
    required this.focus,
    required this.effectiveDate,
    required this.verifiedAsOf,
  });
  final String name;
  final String? symbol;
  final String category;
  final String focus;
  final DateTime effectiveDate;
  final DateTime verifiedAsOf;
}

@immutable
class CovenModel {
  CovenModel({required List<CovenEntry> entries})
    : entries = List.unmodifiable(entries);
  final List<CovenEntry> entries;
}
