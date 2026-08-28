//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'hypothetical_future_mirror_annual_return_bps.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class HypotheticalFutureMirrorAnnualReturnBps {
  /// Returns a new [HypotheticalFutureMirrorAnnualReturnBps] instance.
  HypotheticalFutureMirrorAnnualReturnBps({
    required this.high,

    required this.low,

    required this.mid,
  });

  @JsonKey(name: r'high', required: true, includeIfNull: false)
  final int high;

  @JsonKey(name: r'low', required: true, includeIfNull: false)
  final int low;

  @JsonKey(name: r'mid', required: true, includeIfNull: false)
  final int mid;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HypotheticalFutureMirrorAnnualReturnBps &&
          other.high == high &&
          other.low == low &&
          other.mid == mid;

  @override
  int get hashCode => high.hashCode + low.hashCode + mid.hashCode;

  factory HypotheticalFutureMirrorAnnualReturnBps.fromJson(
    Map<String, dynamic> json,
  ) => _$HypotheticalFutureMirrorAnnualReturnBpsFromJson(json);

  Map<String, dynamic> toJson() =>
      _$HypotheticalFutureMirrorAnnualReturnBpsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
