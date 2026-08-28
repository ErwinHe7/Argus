//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/briefing_detail.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_audit200_response_meta.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'briefing_detail_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BriefingDetailResponse {
  /// Returns a new [BriefingDetailResponse] instance.
  BriefingDetailResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final BriefingDetail data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ListAdminAudit200ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BriefingDetailResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory BriefingDetailResponse.fromJson(Map<String, dynamic> json) =>
      _$BriefingDetailResponseFromJson(json);

  Map<String, dynamic> toJson() => _$BriefingDetailResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
