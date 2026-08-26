//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/collection_meta.dart';
import 'package:ritual_investing_api_client/generated/model/circle_view.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'circle_collection_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CircleCollectionResponse {
  /// Returns a new [CircleCollectionResponse] instance.
  CircleCollectionResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final List<CircleView> data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final CollectionMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CircleCollectionResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory CircleCollectionResponse.fromJson(Map<String, dynamic> json) =>
      _$CircleCollectionResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CircleCollectionResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
