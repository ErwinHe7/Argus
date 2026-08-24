//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/investor_profile.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'put_investor_profile200_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PutInvestorProfile200Response {
  /// Returns a new [PutInvestorProfile200Response] instance.
  PutInvestorProfile200Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final InvestorProfile data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PutInvestorProfile200Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory PutInvestorProfile200Response.fromJson(Map<String, dynamic> json) =>
      _$PutInvestorProfile200ResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PutInvestorProfile200ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
