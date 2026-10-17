// All source data is NYC wall-clock time, and the machine running the
// pipeline (a GitHub runner) is UTC, so never rely on the local timezone.
const TZ = 'America/New_York';

const partsFmt = new Intl.DateTimeFormat('en-US', {
  timeZone: TZ,
  hourCycle: 'h23',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
});

/** Offset of America/New_York from UTC at instant [ms], in ms (negative). */
function nyOffsetMs(ms) {
  const p = Object.fromEntries(
    partsFmt.formatToParts(new Date(ms)).map((x) => [x.type, x.value]),
  );
  const asUtc = Date.UTC(+p.year, +p.month - 1, +p.day, +p.hour, +p.minute, +p.second);
  return asUtc - Math.floor(ms / 1000) * 1000;
}

/** The instant at which NYC clocks read y-mo-d h:mi. DST-safe. */
export function nyWallClockToDate(y, mo, d, h = 0, mi = 0) {
  const guess = Date.UTC(y, mo - 1, d, h, mi);
  const first = guess - nyOffsetMs(guess);
  return new Date(guess - nyOffsetMs(first));
}

/** "2026-10-06T13:30:00.000" / "2026-10-06T00:00:00" / "2026-10-06" -> Date, or null. */
export function parseNyLocalIso(s) {
  const m = /^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2}))?/.exec(String(s ?? '').trim());
  if (!m) return null;
  return nyWallClockToDate(+m[1], +m[2], +m[3], +(m[4] ?? 0), +(m[5] ?? 0));
}

/** "1:30 PM", "0:00 am", "12:00 pm" -> {h, m} (24h) or null. */
export function parseClock(s) {
  const m = /^(\d{1,2}):(\d{2})\s*([ap])\.?m\.?$/i.exec(String(s ?? '').trim());
  if (!m) return null;
  const hour12 = +m[1];
  if (hour12 > 12 || +m[2] > 59) return null;
  const h = (hour12 % 12) + (m[3].toLowerCase() === 'p' ? 12 : 0);
  return { h, m: +m[2] };
}

/** Today's calendar date in NYC as {y, m, d}. */
export function nyToday(now = new Date()) {
  const p = Object.fromEntries(
    partsFmt.formatToParts(now).map((x) => [x.type, x.value]),
  );
  return { y: +p.year, m: +p.month, d: +p.day };
}

/** "YYYY-MM-DD" for a Date, in NYC. */
export function nyDateString(date) {
  const { y, m, d } = nyToday(date);
  return `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
}

/** Human-readable NYC time for dry-run output, e.g. "Tue, Oct 6, 2026, 1:30 PM EDT". */
export function formatNy(date) {
  return date.toLocaleString('en-US', {
    timeZone: TZ,
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    timeZoneName: 'short',
  });
}
