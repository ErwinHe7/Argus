//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/list_briefings200_response_data_inner.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'set_briefing_read_state200_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SetBriefingReadState200Response {
  /// Returns a new [SetBriefingReadState200Response] instance.
  SetBriefingReadState200Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final ListBriefings200ResponseDataInner data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetBriefingReadState200Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory SetBriefingReadState200Response.fromJson(Map<String, dynamic> json) =>
      _$SetBriefingReadState200ResponseFromJson(json);

  Map<String, dynamic> toJson() =>
      _$SetBriefingReadState200ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
