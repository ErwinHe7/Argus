import {
  durableWorkRegistry,
  eventRegistration,
  type DurableEventType,
  type DurableJobHandler,
} from "./registry.ts";

export const retainedJobHandlers = Object.freeze(
  Object.fromEntries(
    Object.entries(durableWorkRegistry.events).map(([eventType, registration]) => [
      eventType,
      registration.handler,
    ]),
  ),
) as Readonly<Record<DurableEventType, DurableJobHandler>>;

export type RetainedEventType = DurableEventType;
export type RetainedJobHandler = DurableJobHandler;

export function handlerForEventType(eventType: string): RetainedJobHandler | null {
  return eventRegistration(eventType)?.handler as RetainedJobHandler | undefined ?? null;
}

export function isRetainedEventType(eventType: string): eventType is RetainedEventType {
  return handlerForEventType(eventType) !== null;
}
