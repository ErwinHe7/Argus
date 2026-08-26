//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'member_account_view_account.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MemberAccountViewAccount {
  /// Returns a new [MemberAccountViewAccount] instance.
  MemberAccountViewAccount({required this.id, required this.status});

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: MemberAccountViewAccountStatusEnum.unknownDefaultOpenApi,
  )
  final MemberAccountViewAccountStatusEnum status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberAccountViewAccount &&
          other.id == id &&
          other.status == status;

  @override
  int get hashCode => id.hashCode + status.hashCode;

  factory MemberAccountViewAccount.fromJson(Map<String, dynamic> json) =>
      _$MemberAccountViewAccountFromJson(json);

  Map<String, dynamic> toJson() => _$MemberAccountViewAccountToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum MemberAccountViewAccountStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const MemberAccountViewAccountStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
