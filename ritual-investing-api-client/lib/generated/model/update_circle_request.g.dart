// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_circle_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$UpdateCircleRequestCWProxy {
  UpdateCircleRequest description(String? description);

  UpdateCircleRequest title(String? title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `UpdateCircleRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// UpdateCircleRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  UpdateCircleRequest call({String? description, String? title});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfUpdateCircleRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfUpdateCircleRequest.copyWith.fieldName(...)`
class _$UpdateCircleRequestCWProxyImpl implements _$UpdateCircleRequestCWProxy {
  const _$UpdateCircleRequestCWProxyImpl(this._value);

  final UpdateCircleRequest _value;

  @override
  UpdateCircleRequest description(String? description) =>
      this(description: description);

  @override
  UpdateCircleRequest title(String? title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `UpdateCircleRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// UpdateCircleRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  UpdateCircleRequest call({
    Object? description = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return UpdateCircleRequest(
      description: description == const $CopyWithPlaceholder()
          ? _value.description
          // ignore: cast_nullable_to_non_nullable
          : description as String?,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String?,
    );
  }
}

extension $UpdateCircleRequestCopyWith on UpdateCircleRequest {
  /// Returns a callable class that can be used as follows: `instanceOfUpdateCircleRequest.copyWith(...)` or like so:`instanceOfUpdateCircleRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$UpdateCircleRequestCWProxy get copyWith =>
      _$UpdateCircleRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateCircleRequest _$UpdateCircleRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('UpdateCircleRequest', json, ($checkedConvert) {
      final val = UpdateCircleRequest(
        description: $checkedConvert('description', (v) => v as String?),
        title: $checkedConvert('title', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$UpdateCircleRequestToJson(
  UpdateCircleRequest instance,
) => <String, dynamic>{
  'description': ?instance.description,
  'title': ?instance.title,
};
