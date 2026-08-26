//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/money.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'future_mirror_view_points_inner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FutureMirrorViewPointsInner {
  /// Returns a new [FutureMirrorViewPointsInner] instance.
  FutureMirrorViewPointsInner({
    required this.date,

    required this.high,

    required this.low,

    required this.mid,
  });

  @JsonKey(name: r'date', required: true, includeIfNull: false)
  final DateTime date;

  @JsonKey(name: r'high', required: true, includeIfNull: false)
  final Money high;

  @JsonKey(name: r'low', required: true, includeIfNull: false)
  final Money low;

  @JsonKey(name: r'mid', required: true, includeIfNull: false)
  final Money mid;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FutureMirrorViewPointsInner &&
          other.date == date &&
          other.high == high &&
          other.low == low &&
          other.mid == mid;

  @override
  int get hashCode =>
      date.hashCode + high.hashCode + low.hashCode + mid.hashCode;

  factory FutureMirrorViewPointsInner.fromJson(Map<String, dynamic> json) =>
      _$FutureMirrorViewPointsInnerFromJson(json);

  Map<String, dynamic> toJson() => _$FutureMirrorViewPointsInnerToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
