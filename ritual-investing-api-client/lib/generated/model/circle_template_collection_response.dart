//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/circle_template_summary.dart';
import 'package:ritual_investing_api_client/generated/model/collection_meta.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'circle_template_collection_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CircleTemplateCollectionResponse {
  /// Returns a new [CircleTemplateCollectionResponse] instance.
  CircleTemplateCollectionResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final List<CircleTemplateSummary> data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final CollectionMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CircleTemplateCollectionResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory CircleTemplateCollectionResponse.fromJson(
    Map<String, dynamic> json,
  ) => _$CircleTemplateCollectionResponseFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CircleTemplateCollectionResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
