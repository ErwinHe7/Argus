//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'daily_ritual_detail_revision.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DailyRitualDetailRevision {
  /// Returns a new [DailyRitualDetailRevision] instance.
  DailyRitualDetailRevision({required this.id, required this.number});

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  // minimum: 0
  @JsonKey(name: r'number', required: true, includeIfNull: false)
  final int number;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyRitualDetailRevision &&
          other.id == id &&
          other.number == number;

  @override
  int get hashCode => id.hashCode + number.hashCode;

  factory DailyRitualDetailRevision.fromJson(Map<String, dynamic> json) =>
      _$DailyRitualDetailRevisionFromJson(json);

  Map<String, dynamic> toJson() => _$DailyRitualDetailRevisionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
