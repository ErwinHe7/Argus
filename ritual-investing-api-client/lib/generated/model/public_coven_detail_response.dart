//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/public_coven_teaser.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'public_coven_detail_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PublicCovenDetailResponse {
  /// Returns a new [PublicCovenDetailResponse] instance.
  PublicCovenDetailResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final PublicCovenTeaser data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicCovenDetailResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory PublicCovenDetailResponse.fromJson(Map<String, dynamic> json) =>
      _$PublicCovenDetailResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PublicCovenDetailResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
