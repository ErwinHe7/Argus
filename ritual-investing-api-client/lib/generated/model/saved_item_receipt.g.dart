// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_item_receipt.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SavedItemReceiptCWProxy {
  SavedItemReceipt saved(bool saved);

  SavedItemReceipt savedAt(DateTime savedAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SavedItemReceipt(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SavedItemReceipt(...).copyWith(id: 12, name: "My name")
  /// ````
  SavedItemReceipt call({bool saved, DateTime savedAt});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSavedItemReceipt.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSavedItemReceipt.copyWith.fieldName(...)`
class _$SavedItemReceiptCWProxyImpl implements _$SavedItemReceiptCWProxy {
  const _$SavedItemReceiptCWProxyImpl(this._value);

  final SavedItemReceipt _value;

  @override
  SavedItemReceipt saved(bool saved) => this(saved: saved);

  @override
  SavedItemReceipt savedAt(DateTime savedAt) => this(savedAt: savedAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SavedItemReceipt(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SavedItemReceipt(...).copyWith(id: 12, name: "My name")
  /// ````
  SavedItemReceipt call({
    Object? saved = const $CopyWithPlaceholder(),
    Object? savedAt = const $CopyWithPlaceholder(),
  }) {
    return SavedItemReceipt(
      saved: saved == const $CopyWithPlaceholder()
          ? _value.saved
          // ignore: cast_nullable_to_non_nullable
          : saved as bool,
      savedAt: savedAt == const $CopyWithPlaceholder()
          ? _value.savedAt
          // ignore: cast_nullable_to_non_nullable
          : savedAt as DateTime,
    );
  }
}

extension $SavedItemReceiptCopyWith on SavedItemReceipt {
  /// Returns a callable class that can be used as follows: `instanceOfSavedItemReceipt.copyWith(...)` or like so:`instanceOfSavedItemReceipt.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SavedItemReceiptCWProxy get copyWith => _$SavedItemReceiptCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SavedItemReceipt _$SavedItemReceiptFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SavedItemReceipt', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['saved', 'saved_at']);
      final val = SavedItemReceipt(
        saved: $checkedConvert('saved', (v) => v as bool),
        savedAt: $checkedConvert(
          'saved_at',
          (v) => DateTime.parse(v as String),
        ),
      );
      return val;
    }, fieldKeyMap: const {'savedAt': 'saved_at'});

Map<String, dynamic> _$SavedItemReceiptToJson(SavedItemReceipt instance) =>
    <String, dynamic>{
      'saved': instance.saved,
      'saved_at': instance.savedAt.toIso8601String(),
    };
