//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'webull_account_selection.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WebullAccountSelection {
  /// Returns a new [WebullAccountSelection] instance.
  WebullAccountSelection({required this.accountId, required this.selected});

  @JsonKey(name: r'account_id', required: true, includeIfNull: false)
  final String accountId;

  @JsonKey(name: r'selected', required: true, includeIfNull: false)
  final bool selected;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebullAccountSelection &&
          other.accountId == accountId &&
          other.selected == selected;

  @override
  int get hashCode => accountId.hashCode + selected.hashCode;

  factory WebullAccountSelection.fromJson(Map<String, dynamic> json) =>
      _$WebullAccountSelectionFromJson(json);

  Map<String, dynamic> toJson() => _$WebullAccountSelectionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
