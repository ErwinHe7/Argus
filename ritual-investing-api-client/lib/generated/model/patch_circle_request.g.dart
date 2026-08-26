// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_circle_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchCircleRequestCWProxy {
  PatchCircleRequest description(String? description);

  PatchCircleRequest title(String? title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchCircleRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchCircleRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchCircleRequest call({String? description, String? title});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchCircleRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchCircleRequest.copyWith.fieldName(...)`
class _$PatchCircleRequestCWProxyImpl implements _$PatchCircleRequestCWProxy {
  const _$PatchCircleRequestCWProxyImpl(this._value);

  final PatchCircleRequest _value;

  @override
  PatchCircleRequest description(String? description) =>
      this(description: description);

  @override
  PatchCircleRequest title(String? title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchCircleRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchCircleRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchCircleRequest call({
    Object? description = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return PatchCircleRequest(
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

extension $PatchCircleRequestCopyWith on PatchCircleRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPatchCircleRequest.copyWith(...)` or like so:`instanceOfPatchCircleRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchCircleRequestCWProxy get copyWith =>
      _$PatchCircleRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchCircleRequest _$PatchCircleRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PatchCircleRequest', json, ($checkedConvert) {
      final val = PatchCircleRequest(
        description: $checkedConvert('description', (v) => v as String?),
        title: $checkedConvert('title', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$PatchCircleRequestToJson(PatchCircleRequest instance) =>
    <String, dynamic>{
      'description': ?instance.description,
      'title': ?instance.title,
    };
