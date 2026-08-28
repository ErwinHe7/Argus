//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_hypothetical_future_mirror_annual_return_bps.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateHypotheticalFutureMirrorAnnualReturnBps {
  /// Returns a new [CreateHypotheticalFutureMirrorAnnualReturnBps] instance.
  CreateHypotheticalFutureMirrorAnnualReturnBps({
    required this.high,

    required this.low,

    required this.mid,
  });

  // minimum: -5000
  // maximum: 5000
  @JsonKey(name: r'high', required: true, includeIfNull: false)
  final int high;

  // minimum: -5000
  // maximum: 5000
  @JsonKey(name: r'low', required: true, includeIfNull: false)
  final int low;

  // minimum: -5000
  // maximum: 5000
  @JsonKey(name: r'mid', required: true, includeIfNull: false)
  final int mid;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateHypotheticalFutureMirrorAnnualReturnBps &&
          other.high == high &&
          other.low == low &&
          other.mid == mid;

  @override
  int get hashCode => high.hashCode + low.hashCode + mid.hashCode;

  factory CreateHypotheticalFutureMirrorAnnualReturnBps.fromJson(
    Map<String, dynamic> json,
  ) => _$CreateHypotheticalFutureMirrorAnnualReturnBpsFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreateHypotheticalFutureMirrorAnnualReturnBpsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
