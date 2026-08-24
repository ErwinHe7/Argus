//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/admin_health_dependencies.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'admin_health.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AdminHealth {
  /// Returns a new [AdminHealth] instance.
  AdminHealth({required this.dependencies, required this.status});

  @JsonKey(name: r'dependencies', required: true, includeIfNull: false)
  final AdminHealthDependencies dependencies;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AdminHealthStatusEnum.unknownDefaultOpenApi,
  )
  final AdminHealthStatusEnum status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminHealth &&
          other.dependencies == dependencies &&
          other.status == status;

  @override
  int get hashCode => dependencies.hashCode + status.hashCode;

  factory AdminHealth.fromJson(Map<String, dynamic> json) =>
      _$AdminHealthFromJson(json);

  Map<String, dynamic> toJson() => _$AdminHealthToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum AdminHealthStatusEnum {
  @JsonValue(r'ready')
  ready(r'ready'),
  @JsonValue(r'degraded')
  degraded(r'degraded'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const AdminHealthStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
