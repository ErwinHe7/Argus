//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/saved_item_receipt.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'save_asset200_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SaveAsset200Response {
  /// Returns a new [SaveAsset200Response] instance.
  SaveAsset200Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final SavedItemReceipt data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaveAsset200Response && other.data == data && other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory SaveAsset200Response.fromJson(Map<String, dynamic> json) =>
      _$SaveAsset200ResponseFromJson(json);

  Map<String, dynamic> toJson() => _$SaveAsset200ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
