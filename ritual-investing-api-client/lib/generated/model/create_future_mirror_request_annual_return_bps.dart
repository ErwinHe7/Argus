//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_future_mirror_request_annual_return_bps.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateFutureMirrorRequestAnnualReturnBps {
  /// Returns a new [CreateFutureMirrorRequestAnnualReturnBps] instance.
  CreateFutureMirrorRequestAnnualReturnBps({
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
      other is CreateFutureMirrorRequestAnnualReturnBps &&
          other.high == high &&
          other.low == low &&
          other.mid == mid;

  @override
  int get hashCode => high.hashCode + low.hashCode + mid.hashCode;

  factory CreateFutureMirrorRequestAnnualReturnBps.fromJson(
    Map<String, dynamic> json,
  ) => _$CreateFutureMirrorRequestAnnualReturnBpsFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreateFutureMirrorRequestAnnualReturnBpsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
