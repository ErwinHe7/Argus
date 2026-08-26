//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/public_coven_teaser.dart';
import 'package:ritual_investing_api_client/generated/model/collection_meta.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'public_coven_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PublicCovenResponse {
  /// Returns a new [PublicCovenResponse] instance.
  PublicCovenResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final List<PublicCovenTeaser> data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final CollectionMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicCovenResponse && other.data == data && other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory PublicCovenResponse.fromJson(Map<String, dynamic> json) =>
      _$PublicCovenResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PublicCovenResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
