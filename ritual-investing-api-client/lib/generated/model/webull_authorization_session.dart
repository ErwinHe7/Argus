//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'webull_authorization_session.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WebullAuthorizationSession {
  /// Returns a new [WebullAuthorizationSession] instance.
  WebullAuthorizationSession({
    required this.authorizationUrl,

    required this.connectionId,

    required this.expiresAt,
  });

  @JsonKey(name: r'authorization_url', required: true, includeIfNull: false)
  final String authorizationUrl;

  @JsonKey(name: r'connection_id', required: true, includeIfNull: false)
  final String connectionId;

  @JsonKey(name: r'expires_at', required: true, includeIfNull: false)
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebullAuthorizationSession &&
          other.authorizationUrl == authorizationUrl &&
          other.connectionId == connectionId &&
          other.expiresAt == expiresAt;

  @override
  int get hashCode =>
      authorizationUrl.hashCode + connectionId.hashCode + expiresAt.hashCode;

  factory WebullAuthorizationSession.fromJson(Map<String, dynamic> json) =>
      _$WebullAuthorizationSessionFromJson(json);

  Map<String, dynamic> toJson() => _$WebullAuthorizationSessionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
