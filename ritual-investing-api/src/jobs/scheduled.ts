export const retainedJobHandlers = Object.freeze({
  "briefing.daily.requested": "briefing-builder",
  "briefing.weekly.requested": "briefing-builder",
  "briefing.moon_cycle.requested": "briefing-builder",
  "briefing.daily.generated": "notification-writer",
  "briefing.weekly.generated": "notification-writer",
  "briefing.moon_cycle.generated": "notification-writer",
  "media.scan.requested": "media-scan",
  "media.quarantine.cleanup": "media-cleanup",
  "content-report.created": "moderation-triage",
  "privacy.export.requested": "privacy-export",
  "privacy.deletion.requested": "privacy-purge",
  "privacy.export.retention.requested": "privacy-export-retention",
} as const);

export type RetainedEventType = keyof typeof retainedJobHandlers;
export type RetainedJobHandler = (typeof retainedJobHandlers)[RetainedEventType];

export function handlerForEventType(eventType: string): RetainedJobHandler | null {
  return Object.prototype.hasOwnProperty.call(retainedJobHandlers, eventType)
    ? retainedJobHandlers[eventType as RetainedEventType]
    : null;
}

export function isRetainedEventType(eventType: string): eventType is RetainedEventType {
  return handlerForEventType(eventType) !== null;
}
