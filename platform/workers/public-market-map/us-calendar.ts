/** Published XNYS core-session schedule, verified 2026-09-04 against NYSE.
 * This bounded schedule does not guess holidays beyond the published years.
 * Emergency closures require a calendar update; a missing source day fails closed.
 */
export const US_CALENDAR_SOURCE = 'https://www.nyse.com/trade/hours-calendars';
export const US_CALENDAR_VERIFIED_AT = '2026-09-04T12:53:28.000Z';
export const US_CALENDAR_START = '2026-01-01';
export const US_CALENDAR_END = '2028-12-31';
const closed = new Set([
  '2026-01-01', '2026-01-19', '2026-02-16', '2026-04-03', '2026-05-25', '2026-06-19', '2026-07-03', '2026-09-07', '2026-11-26', '2026-12-25',
  '2027-01-01', '2027-01-18', '2027-02-15', '2027-03-26', '2027-05-31', '2027-06-18', '2027-07-05', '2027-09-06', '2027-11-25', '2027-12-24',
  '2028-01-17', '2028-02-21', '2028-04-14', '2028-05-29', '2028-06-19', '2028-07-04', '2028-09-04', '2028-11-23', '2028-12-25',
]);
const early = new Set(['2026-11-27', '2026-12-24', '2027-11-26', '2028-07-03', '2028-11-24']);
export type UsSession = { date: string; open: string; close: string };

function easternTime(date: string, hour: number, minute = 0): string {
  const noon = new Date(`${date}T12:00:00Z`);
  const offset = new Intl.DateTimeFormat('en-US', { timeZone: 'America/New_York', hour: 'numeric', hourCycle: 'h23' }).format(noon);
  const offsetHours = Number(offset) - 12;
  return new Date(Date.parse(`${date}T00:00:00Z`) + ((hour - offsetHours) * 60 + minute) * 60000).toISOString();
}

export function usSessions(start: string, end: string): UsSession[] {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(start) || !/^\d{4}-\d{2}-\d{2}$/.test(end) || start < US_CALENDAR_START || end > US_CALENDAR_END || end < start) throw new Error('us_calendar_out_of_range');
  const sessions: UsSession[] = [];
  for (let epoch = Date.parse(`${start}T00:00:00Z`); epoch <= Date.parse(`${end}T00:00:00Z`); epoch += 86400000) {
    const date = new Date(epoch), day = date.toISOString().slice(0, 10);
    if ([0, 6].includes(date.getUTCDay()) || closed.has(day)) continue;
    sessions.push({ date: day, open: easternTime(day, 9, 30), close: easternTime(day, early.has(day) ? 13 : 16) });
  }
  return sessions;
}

/** An operational T+1 target, never used as the actual source available_at.
 * The upstream job starts at 06:00 UTC and may finish later than 08:00 UTC.
 */
export const hfPublicationAt = (sessionDate: string): number => Date.parse(`${sessionDate}T00:00:00Z`) + 32 * 3600000;
export const hfRefreshDeadline = (sessionDate: string): number => Date.parse(`${sessionDate}T00:00:00Z`) + 38.5 * 3600000;
