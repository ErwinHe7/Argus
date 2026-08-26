//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/collection_meta.dart';
import 'package:ritual_investing_api_client/generated/model/seeded_creator.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'creator_collection_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreatorCollectionResponse {
  /// Returns a new [CreatorCollectionResponse] instance.
  CreatorCollectionResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final List<SeededCreator> data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final CollectionMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreatorCollectionResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory CreatorCollectionResponse.fromJson(Map<String, dynamic> json) =>
      _$CreatorCollectionResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CreatorCollectionResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
