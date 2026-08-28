//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'hypothetical_future_mirror_point.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class HypotheticalFutureMirrorPoint {
  /// Returns a new [HypotheticalFutureMirrorPoint] instance.
  HypotheticalFutureMirrorPoint({
    required this.highAmountMinor,

    required this.lowAmountMinor,

    required this.midAmountMinor,

    required this.ordinal,

    required this.projectedDate,
  });

  @JsonKey(name: r'high_amount_minor', required: true, includeIfNull: false)
  final String highAmountMinor;

  @JsonKey(name: r'low_amount_minor', required: true, includeIfNull: false)
  final String lowAmountMinor;

  @JsonKey(name: r'mid_amount_minor', required: true, includeIfNull: false)
  final String midAmountMinor;

  // minimum: 0
  @JsonKey(name: r'ordinal', required: true, includeIfNull: false)
  final int ordinal;

  @JsonKey(name: r'projected_date', required: true, includeIfNull: false)
  final DateTime projectedDate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HypotheticalFutureMirrorPoint &&
          other.highAmountMinor == highAmountMinor &&
          other.lowAmountMinor == lowAmountMinor &&
          other.midAmountMinor == midAmountMinor &&
          other.ordinal == ordinal &&
          other.projectedDate == projectedDate;

  @override
  int get hashCode =>
      highAmountMinor.hashCode +
      lowAmountMinor.hashCode +
      midAmountMinor.hashCode +
      ordinal.hashCode +
      projectedDate.hashCode;

  factory HypotheticalFutureMirrorPoint.fromJson(Map<String, dynamic> json) =>
      _$HypotheticalFutureMirrorPointFromJson(json);

  Map<String, dynamic> toJson() => _$HypotheticalFutureMirrorPointToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
