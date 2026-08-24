//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/ritual_history_item.dart';
import 'package:ritual_investing_api_client/generated/model/collection_meta.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ritual_history_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RitualHistoryResponse {
  /// Returns a new [RitualHistoryResponse] instance.
  RitualHistoryResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final List<RitualHistoryItem> data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final CollectionMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RitualHistoryResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory RitualHistoryResponse.fromJson(Map<String, dynamic> json) =>
      _$RitualHistoryResponseFromJson(json);

  Map<String, dynamic> toJson() => _$RitualHistoryResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
