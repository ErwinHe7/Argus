import 'package:flutter/foundation.dart';

@immutable
class ProfileModel {
  const ProfileModel({required this.displayName});
  final String displayName;
}
