//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'session_bootstrap_account.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SessionBootstrapAccount {
  /// Returns a new [SessionBootstrapAccount] instance.
  SessionBootstrapAccount({required this.id, required this.status});

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: SessionBootstrapAccountStatusEnum.unknownDefaultOpenApi,
  )
  final SessionBootstrapAccountStatusEnum status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionBootstrapAccount &&
          other.id == id &&
          other.status == status;

  @override
  int get hashCode => id.hashCode + status.hashCode;

  factory SessionBootstrapAccount.fromJson(Map<String, dynamic> json) =>
      _$SessionBootstrapAccountFromJson(json);

  Map<String, dynamic> toJson() => _$SessionBootstrapAccountToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum SessionBootstrapAccountStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const SessionBootstrapAccountStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
