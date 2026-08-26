//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/create_future_mirror_request_annual_return_bps.dart';
import 'package:ritual_investing_api_client/generated/model/input_money.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_future_mirror_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateFutureMirrorRequest {
  /// Returns a new [CreateFutureMirrorRequest] instance.
  CreateFutureMirrorRequest({
    required this.annualReturnBps,

    required this.monthlyContribution,

    required this.name,
  });

  @JsonKey(name: r'annual_return_bps', required: true, includeIfNull: false)
  final CreateFutureMirrorRequestAnnualReturnBps annualReturnBps;

  @JsonKey(name: r'monthly_contribution', required: true, includeIfNull: false)
  final InputMoney monthlyContribution;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateFutureMirrorRequest &&
          other.annualReturnBps == annualReturnBps &&
          other.monthlyContribution == monthlyContribution &&
          other.name == name;

  @override
  int get hashCode =>
      annualReturnBps.hashCode + monthlyContribution.hashCode + name.hashCode;

  factory CreateFutureMirrorRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateFutureMirrorRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateFutureMirrorRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
