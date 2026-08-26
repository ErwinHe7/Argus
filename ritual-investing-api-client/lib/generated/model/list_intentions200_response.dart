//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/collection_meta.dart';
import 'package:ritual_investing_api_client/generated/model/intention.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_intentions200_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListIntentions200Response {
  /// Returns a new [ListIntentions200Response] instance.
  ListIntentions200Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final List<Intention> data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final CollectionMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListIntentions200Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory ListIntentions200Response.fromJson(Map<String, dynamic> json) =>
      _$ListIntentions200ResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ListIntentions200ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
