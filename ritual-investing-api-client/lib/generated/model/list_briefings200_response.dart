//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/collection_meta.dart';
import 'package:ritual_investing_api_client/generated/model/list_briefings200_response_data_inner.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_briefings200_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListBriefings200Response {
  /// Returns a new [ListBriefings200Response] instance.
  ListBriefings200Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final List<ListBriefings200ResponseDataInner> data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final CollectionMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListBriefings200Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory ListBriefings200Response.fromJson(Map<String, dynamic> json) =>
      _$ListBriefings200ResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ListBriefings200ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
