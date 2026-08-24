import 'package:flutter/foundation.dart';

@immutable
class DailyRitual {
  const DailyRitual({required this.title, required this.interpretation});
  final String title;
  final String interpretation;
  @override
  bool operator ==(Object other) =>
      other is DailyRitual &&
      other.title == title &&
      other.interpretation == interpretation;
  @override
  int get hashCode => Object.hash(title, interpretation);
}
