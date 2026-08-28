// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_intention_page.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemberIntentionPageCWProxy {
  MemberIntentionPage items(List<MemberIntention> items);

  MemberIntentionPage nextCursor(String? nextCursor);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberIntentionPage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberIntentionPage(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberIntentionPage call({List<MemberIntention> items, String? nextCursor});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMemberIntentionPage.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMemberIntentionPage.copyWith.fieldName(...)`
class _$MemberIntentionPageCWProxyImpl implements _$MemberIntentionPageCWProxy {
  const _$MemberIntentionPageCWProxyImpl(this._value);

  final MemberIntentionPage _value;

  @override
  MemberIntentionPage items(List<MemberIntention> items) => this(items: items);

  @override
  MemberIntentionPage nextCursor(String? nextCursor) =>
      this(nextCursor: nextCursor);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberIntentionPage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberIntentionPage(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberIntentionPage call({
    Object? items = const $CopyWithPlaceholder(),
    Object? nextCursor = const $CopyWithPlaceholder(),
  }) {
    return MemberIntentionPage(
      items: items == const $CopyWithPlaceholder()
          ? _value.items
          // ignore: cast_nullable_to_non_nullable
          : items as List<MemberIntention>,
      nextCursor: nextCursor == const $CopyWithPlaceholder()
          ? _value.nextCursor
          // ignore: cast_nullable_to_non_nullable
          : nextCursor as String?,
    );
  }
}

extension $MemberIntentionPageCopyWith on MemberIntentionPage {
  /// Returns a callable class that can be used as follows: `instanceOfMemberIntentionPage.copyWith(...)` or like so:`instanceOfMemberIntentionPage.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MemberIntentionPageCWProxy get copyWith =>
      _$MemberIntentionPageCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemberIntentionPage _$MemberIntentionPageFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MemberIntentionPage', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['items', 'next_cursor']);
      final val = MemberIntentionPage(
        items: $checkedConvert(
          'items',
          (v) => (v as List<dynamic>)
              .map((e) => MemberIntention.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        nextCursor: $checkedConvert('next_cursor', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {'nextCursor': 'next_cursor'});

Map<String, dynamic> _$MemberIntentionPageToJson(
  MemberIntentionPage instance,
) => <String, dynamic>{
  'items': instance.items.map((e) => e.toJson()).toList(),
  'next_cursor': instance.nextCursor,
};
