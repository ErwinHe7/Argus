//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'select_webull_account_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SelectWebullAccountRequest {
  /// Returns a new [SelectWebullAccountRequest] instance.
  SelectWebullAccountRequest({required this.accountId});

  @JsonKey(name: r'account_id', required: true, includeIfNull: false)
  final String accountId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectWebullAccountRequest && other.accountId == accountId;

  @override
  int get hashCode => accountId.hashCode;

  factory SelectWebullAccountRequest.fromJson(Map<String, dynamic> json) =>
      _$SelectWebullAccountRequestFromJson(json);

  Map<String, dynamic> toJson() => _$SelectWebullAccountRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
