//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'admin_health_dependencies.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AdminHealthDependencies {
  /// Returns a new [AdminHealthDependencies] instance.
  AdminHealthDependencies({
    required this.identity,

    required this.media,

    required this.neon,

    required this.queue,
  });

  @JsonKey(
    name: r'identity',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AdminHealthDependenciesIdentityEnum.unknownDefaultOpenApi,
  )
  final AdminHealthDependenciesIdentityEnum identity;

  @JsonKey(
    name: r'media',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AdminHealthDependenciesMediaEnum.unknownDefaultOpenApi,
  )
  final AdminHealthDependenciesMediaEnum media;

  @JsonKey(
    name: r'neon',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AdminHealthDependenciesNeonEnum.unknownDefaultOpenApi,
  )
  final AdminHealthDependenciesNeonEnum neon;

  @JsonKey(
    name: r'queue',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AdminHealthDependenciesQueueEnum.unknownDefaultOpenApi,
  )
  final AdminHealthDependenciesQueueEnum queue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminHealthDependencies &&
          other.identity == identity &&
          other.media == media &&
          other.neon == neon &&
          other.queue == queue;

  @override
  int get hashCode =>
      identity.hashCode + media.hashCode + neon.hashCode + queue.hashCode;

  factory AdminHealthDependencies.fromJson(Map<String, dynamic> json) =>
      _$AdminHealthDependenciesFromJson(json);

  Map<String, dynamic> toJson() => _$AdminHealthDependenciesToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum AdminHealthDependenciesIdentityEnum {
  @JsonValue(r'configured')
  configured(r'configured'),
  @JsonValue(r'missing')
  missing(r'missing'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const AdminHealthDependenciesIdentityEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum AdminHealthDependenciesMediaEnum {
  @JsonValue(r'configured')
  configured(r'configured'),
  @JsonValue(r'missing')
  missing(r'missing'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const AdminHealthDependenciesMediaEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum AdminHealthDependenciesNeonEnum {
  @JsonValue(r'configured')
  configured(r'configured'),
  @JsonValue(r'missing')
  missing(r'missing'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const AdminHealthDependenciesNeonEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum AdminHealthDependenciesQueueEnum {
  @JsonValue(r'configured')
  configured(r'configured'),
  @JsonValue(r'missing')
  missing(r'missing'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const AdminHealthDependenciesQueueEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
