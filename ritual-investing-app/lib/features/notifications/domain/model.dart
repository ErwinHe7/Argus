import 'package:flutter/foundation.dart';

enum NotificationKind { briefingReady }

enum NotificationReadFilter { all, read, unread }

@immutable
class NotificationDestination {
  const NotificationDestination._(this.location);

  final String location;

  static NotificationDestination? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    final segments = uri.pathSegments;
    if (segments.length == 1 && segments.single == 'briefings') {
      return const NotificationDestination._('/gospel/briefings');
    }
    if (segments.length == 2 &&
        segments.first == 'briefings' &&
        _isUuid(segments[1])) {
      return NotificationDestination._('/gospel/briefings/${segments[1]}');
    }
    if (segments.length == 1 && segments.single == 'ritual') {
      return const NotificationDestination._('/gospel');
    }
    final assetId = switch (segments) {
      ['assets', final id] => id,
      ['discover', 'assets', final id] => id,
      _ => null,
    };
    if (assetId != null && _isUuid(assetId)) {
      // Notification is not an authority-supported asset provenance. Keep the
      // stable in-app destination while allowing Asset Codex to treat the
      // navigation as direct.
      return NotificationDestination._('/discover/assets/$assetId');
    }
    final portfolioId = switch (segments) {
      ['portfolios', final id] => id,
      ['you', 'portfolios', final id] => id,
      _ => null,
    };
    if (portfolioId != null && _isStableId(portfolioId)) {
      return NotificationDestination._('/you/portfolios/$portfolioId');
    }
    return null;
  }
}

@immutable
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.destination,
    required this.scheduledAt,
    required this.readAt,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final NotificationDestination? destination;
  final DateTime? scheduledAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  NotificationItem copyWith({DateTime? readAt, bool clearReadAt = false}) =>
      NotificationItem(
        id: id,
        kind: kind,
        title: title,
        body: body,
        destination: destination,
        scheduledAt: scheduledAt,
        readAt: clearReadAt ? null : readAt ?? this.readAt,
      );
}

@immutable
class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<NotificationItem> items;
  final bool hasMore;
  final String? nextCursor;
}

@immutable
class NotificationQuietHours {
  const NotificationQuietHours({
    required this.enabled,
    required this.start,
    required this.end,
    required this.timezone,
  });

  final bool enabled;
  final String start;
  final String end;
  final String timezone;
}

@immutable
class NotificationPreferences {
  const NotificationPreferences({
    required this.dailyRitual,
    required this.weeklyRecap,
    required this.moonCycle,
    required this.quietHours,
    required this.version,
  });

  final bool dailyRitual;
  final bool weeklyRecap;
  final bool moonCycle;
  final NotificationQuietHours quietHours;
  final int version;

  NotificationPreferences copyWith({
    bool? dailyRitual,
    bool? weeklyRecap,
    bool? moonCycle,
    NotificationQuietHours? quietHours,
    int? version,
  }) => NotificationPreferences(
    dailyRitual: dailyRitual ?? this.dailyRitual,
    weeklyRecap: weeklyRecap ?? this.weeklyRecap,
    moonCycle: moonCycle ?? this.moonCycle,
    quietHours: quietHours ?? this.quietHours,
    version: version ?? this.version,
  );

  NotificationPreferencesDraft asDraft() => NotificationPreferencesDraft(
    dailyRitual: dailyRitual,
    weeklyRecap: weeklyRecap,
    moonCycle: moonCycle,
    quietHours: quietHours,
  );
}

@immutable
class NotificationPreferencesDraft {
  const NotificationPreferencesDraft({
    required this.dailyRitual,
    required this.weeklyRecap,
    required this.moonCycle,
    required this.quietHours,
  });

  factory NotificationPreferencesDraft.fromPreferences(
    NotificationPreferences value,
  ) => value.asDraft();

  final bool dailyRitual;
  final bool weeklyRecap;
  final bool moonCycle;
  final NotificationQuietHours quietHours;

  NotificationPreferences toPreferences({required int version}) =>
      NotificationPreferences(
        dailyRitual: dailyRitual,
        weeklyRecap: weeklyRecap,
        moonCycle: moonCycle,
        quietHours: quietHours,
        version: version,
      );

  bool exactlyMatches(NotificationPreferences value) =>
      dailyRitual == value.dailyRitual &&
      weeklyRecap == value.weeklyRecap &&
      moonCycle == value.moonCycle &&
      quietHours.enabled == value.quietHours.enabled &&
      quietHours.start == value.quietHours.start &&
      quietHours.end == value.quietHours.end &&
      quietHours.timezone == value.quietHours.timezone;
}

@immutable
class NotificationReadAll {
  const NotificationReadAll({
    required this.before,
    required this.idempotencyKey,
  });

  final DateTime before;
  final String idempotencyKey;
}

class AmbiguousNotificationReadAll implements Exception {
  const AmbiguousNotificationReadAll();
}

class AmbiguousNotificationPreferences implements Exception {
  const AmbiguousNotificationPreferences();
}

bool _isUuid(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
).hasMatch(value);

bool _isStableId(String value) =>
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(value);
