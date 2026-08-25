import 'package:flutter/foundation.dart';

enum RowanSurface { dailyRitual, evidence, assetCodex, coven }

@immutable
class RowanRequest {
  RowanRequest._(this.surface, this.contextCode, this.resourceId) {
    if (!_uuid.hasMatch(resourceId)) {
      throw ArgumentError.value(
        resourceId,
        'resourceId',
        'Rowan resources must be stable UUIDs.',
      );
    }
  }

  factory RowanRequest.dailyRitual(String assignmentId) =>
      RowanRequest._(RowanSurface.dailyRitual, 'daily', assignmentId);

  factory RowanRequest.evidence(String assignmentId) =>
      RowanRequest._(RowanSurface.evidence, 'evidence', assignmentId);

  factory RowanRequest.assetCodex(String assetId) =>
      RowanRequest._(RowanSurface.assetCodex, 'asset', assetId);

  factory RowanRequest.coven(String covenId) =>
      RowanRequest._(RowanSurface.coven, 'coven', covenId);

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  final RowanSurface surface;
  final String contextCode;
  final String resourceId;

  String get cacheKey =>
      'rowan:${surface.name}:$contextCode:${Uri.encodeComponent(resourceId)}';
}

@immutable
class RowanCounselResult {
  const RowanCounselResult({
    required this.scriptRevisionId,
    required this.surface,
    required this.body,
    required this.riskFooter,
  });

  final String scriptRevisionId;
  final RowanSurface surface;
  final String body;
  final String riskFooter;
}
