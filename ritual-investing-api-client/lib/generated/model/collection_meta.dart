//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'collection_meta.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CollectionMeta {
  /// Returns a new [CollectionMeta] instance.
  CollectionMeta({
    required this.hasMore,

    required this.nextCursor,

    required this.requestId,
  });

  @JsonKey(name: r'has_more', required: true, includeIfNull: false)
  final bool hasMore;

  @JsonKey(name: r'next_cursor', required: true, includeIfNull: true)
  final String? nextCursor;

  /// Server-assigned request correlation identifier.
  @JsonKey(name: r'request_id', required: true, includeIfNull: false)
  final String requestId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollectionMeta &&
          other.hasMore == hasMore &&
          other.nextCursor == nextCursor &&
          other.requestId == requestId;

  @override
  int get hashCode =>
      hasMore.hashCode +
      (nextCursor == null ? 0 : nextCursor.hashCode) +
      requestId.hashCode;

  factory CollectionMeta.fromJson(Map<String, dynamic> json) =>
      _$CollectionMetaFromJson(json);

  Map<String, dynamic> toJson() => _$CollectionMetaToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
