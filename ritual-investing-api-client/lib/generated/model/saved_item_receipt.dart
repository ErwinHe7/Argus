//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'saved_item_receipt.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SavedItemReceipt {
  /// Returns a new [SavedItemReceipt] instance.
  SavedItemReceipt({required this.saved, required this.savedAt});

  @JsonKey(name: r'saved', required: true, includeIfNull: false)
  final bool saved;

  @JsonKey(name: r'saved_at', required: true, includeIfNull: false)
  final DateTime savedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedItemReceipt &&
          other.saved == saved &&
          other.savedAt == savedAt;

  @override
  int get hashCode => saved.hashCode + savedAt.hashCode;

  factory SavedItemReceipt.fromJson(Map<String, dynamic> json) =>
      _$SavedItemReceiptFromJson(json);

  Map<String, dynamic> toJson() => _$SavedItemReceiptToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
