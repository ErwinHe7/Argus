//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/member_account_view.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'member_account_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MemberAccountResponse {
  /// Returns a new [MemberAccountResponse] instance.
  MemberAccountResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final MemberAccountView data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberAccountResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory MemberAccountResponse.fromJson(Map<String, dynamic> json) =>
      _$MemberAccountResponseFromJson(json);

  Map<String, dynamic> toJson() => _$MemberAccountResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
