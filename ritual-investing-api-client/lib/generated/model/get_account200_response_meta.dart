//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'get_account200_response_meta.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class GetAccount200ResponseMeta {
  /// Returns a new [GetAccount200ResponseMeta] instance.
  GetAccount200ResponseMeta({required this.requestId});

  @JsonKey(name: r'request_id', required: true, includeIfNull: false)
  final String requestId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GetAccount200ResponseMeta && other.requestId == requestId;

  @override
  int get hashCode => requestId.hashCode;

  factory GetAccount200ResponseMeta.fromJson(Map<String, dynamic> json) =>
      _$GetAccount200ResponseMetaFromJson(json);

  Map<String, dynamic> toJson() => _$GetAccount200ResponseMetaToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
