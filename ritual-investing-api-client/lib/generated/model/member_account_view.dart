//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/member_profile.dart';
import 'package:ritual_investing_api_client/generated/model/member_account_view_account.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'member_account_view.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MemberAccountView {
  /// Returns a new [MemberAccountView] instance.
  MemberAccountView({required this.account, required this.profile});

  @JsonKey(name: r'account', required: true, includeIfNull: false)
  final MemberAccountViewAccount account;

  @JsonKey(name: r'profile', required: true, includeIfNull: false)
  final MemberProfile profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberAccountView &&
          other.account == account &&
          other.profile == profile;

  @override
  int get hashCode => account.hashCode + profile.hashCode;

  factory MemberAccountView.fromJson(Map<String, dynamic> json) =>
      _$MemberAccountViewFromJson(json);

  Map<String, dynamic> toJson() => _$MemberAccountViewToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
