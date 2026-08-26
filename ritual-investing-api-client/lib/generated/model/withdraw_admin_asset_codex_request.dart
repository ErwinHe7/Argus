//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'withdraw_admin_asset_codex_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WithdrawAdminAssetCodexRequest {
  /// Returns a new [WithdrawAdminAssetCodexRequest] instance.
  WithdrawAdminAssetCodexRequest({required this.reason});

  @JsonKey(name: r'reason', required: true, includeIfNull: false)
  final String reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WithdrawAdminAssetCodexRequest && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  factory WithdrawAdminAssetCodexRequest.fromJson(Map<String, dynamic> json) =>
      _$WithdrawAdminAssetCodexRequestFromJson(json);

  Map<String, dynamic> toJson() => _$WithdrawAdminAssetCodexRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
