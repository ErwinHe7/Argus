//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/rebalance_preview.dart';
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_rebalance_preview200_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateRebalancePreview200Response {
  /// Returns a new [CreateRebalancePreview200Response] instance.
  CreateRebalancePreview200Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final RebalancePreview data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateRebalancePreview200Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory CreateRebalancePreview200Response.fromJson(
    Map<String, dynamic> json,
  ) => _$CreateRebalancePreview200ResponseFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreateRebalancePreview200ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
