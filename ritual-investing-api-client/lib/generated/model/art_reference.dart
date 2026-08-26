//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'art_reference.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ArtReference {
  /// Returns a new [ArtReference] instance.
  ArtReference({required this.alt, required this.key});

  @JsonKey(name: r'alt', required: true, includeIfNull: false)
  final String alt;

  @JsonKey(
    name: r'key',
    required: true,
    includeIfNull: false,
    unknownEnumValue: ArtReferenceKeyEnum.unknownDefaultOpenApi,
  )
  final ArtReferenceKeyEnum key;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArtReference && other.alt == alt && other.key == key;

  @override
  int get hashCode => alt.hashCode + key.hashCode;

  factory ArtReference.fromJson(Map<String, dynamic> json) =>
      _$ArtReferenceFromJson(json);

  Map<String, dynamic> toJson() => _$ArtReferenceToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum ArtReferenceKeyEnum {
  @JsonValue(r'the_compass')
  theCompass(r'the_compass'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ArtReferenceKeyEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
