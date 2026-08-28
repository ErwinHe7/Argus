//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/get_account200_response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/hypothetical_future_mirror.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'hypothetical_future_mirror_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class HypotheticalFutureMirrorResponse {
  /// Returns a new [HypotheticalFutureMirrorResponse] instance.
  HypotheticalFutureMirrorResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final HypotheticalFutureMirror data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final GetAccount200ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HypotheticalFutureMirrorResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory HypotheticalFutureMirrorResponse.fromJson(
    Map<String, dynamic> json,
  ) => _$HypotheticalFutureMirrorResponseFromJson(json);

  Map<String, dynamic> toJson() =>
      _$HypotheticalFutureMirrorResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
