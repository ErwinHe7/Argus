//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'response_meta.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ResponseMeta {
  /// Returns a new [ResponseMeta] instance.
  ResponseMeta({required this.requestId});

  /// Server-assigned request correlation identifier.
  @JsonKey(name: r'request_id', required: true, includeIfNull: false)
  final String requestId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResponseMeta && other.requestId == requestId;

  @override
  int get hashCode => requestId.hashCode;

  factory ResponseMeta.fromJson(Map<String, dynamic> json) =>
      _$ResponseMetaFromJson(json);

  Map<String, dynamic> toJson() => _$ResponseMetaToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
