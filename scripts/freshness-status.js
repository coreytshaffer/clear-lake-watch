// Observation-age evaluation for the Clear Lake Watch dashboard.
//
// Every function here is pure: the caller supplies the evaluation clock
// (`asOfMs`, epoch milliseconds) and nothing reads the ambient clock. The
// dashboard captures one clock value per page load and passes it in.
//
// The evaluation mode selects an age rule. It confers no publication
// authority and never makes an observation "current."

export const SOURCE_TIME_ZONE = "America/Los_Angeles";

export const OPERATIONAL = "operational";
export const REVIEWED_SNAPSHOT = "reviewed_snapshot";

const MS_PER_DAY = 86_400_000;
// ECMAScript time values are limited to +/-8.64e15 ms around the epoch.
const MAX_TIME_VALUE = 8.64e15;

const DATE_ONLY_PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/;
// Offset-bearing instants only: `Z` or `+HH:MM` / `-HH:MM`, with optional
// fractional seconds of one to nine digits.
const OFFSET_INSTANT_PATTERN =
  /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,9}))?(?:Z|([+-])(\d{2}):(\d{2}))$/;

const isLeapYear = (year) =>
  (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0;

const daysInMonth = (year, month) =>
  [31, isLeapYear(year) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1];

const isGregorianDate = (year, month, day) =>
  month >= 1 && month <= 12 && day >= 1 && day <= daysInMonth(year, month);

// Days since 1970-01-01 for a proleptic Gregorian calendar date. setUTCFullYear
// avoids Date.UTC's remapping of years 0-99 to the twentieth century.
const dayOrdinal = ({ year, month, day }) => {
  const date = new Date(0);
  date.setUTCFullYear(year, month - 1, day);
  return date.getTime() / MS_PER_DAY;
};

const parseDateOnly = (value) => {
  if (typeof value !== "string") {
    return null;
  }

  const match = DATE_ONLY_PATTERN.exec(value);

  if (!match) {
    return null;
  }

  const [year, month, day] = match.slice(1, 4).map(Number);
  return isGregorianDate(year, month, day) ? { year, month, day } : null;
};

const isClock = (value) =>
  typeof value === "number" && Number.isFinite(value) && Math.abs(value) <= MAX_TIME_VALUE;

/**
 * Parse an offset-bearing ISO 8601 instant to epoch milliseconds.
 *
 * Real Gregorian dates and time components are validated before parsing, and
 * fractional seconds are truncated (never rounded) to milliseconds. Returns
 * null for anything else, including offset-free local datetimes, date-only
 * strings, and non-string input.
 *
 * @param {unknown} value
 * @returns {number | null}
 */
export const parseInstant = (value) => {
  if (typeof value !== "string") {
    return null;
  }

  const match = OFFSET_INSTANT_PATTERN.exec(value);

  if (!match) {
    return null;
  }

  const [, yearText, monthText, dayText, hourText, minuteText, secondText] = match;
  const [, , , , , , , fraction = "", offsetSign, offsetHourText, offsetMinuteText] = match;
  const year = Number(yearText);
  const month = Number(monthText);
  const day = Number(dayText);
  const hour = Number(hourText);
  const minute = Number(minuteText);
  const second = Number(secondText);

  if (!isGregorianDate(year, month, day) || hour > 23 || minute > 59 || second > 59) {
    return null;
  }

  let offsetMinutes = 0;

  if (offsetSign) {
    const offsetHour = Number(offsetHourText);
    const offsetMinute = Number(offsetMinuteText);

    if (offsetHour > 23 || offsetMinute > 59) {
      return null;
    }

    offsetMinutes = (offsetSign === "-" ? -1 : 1) * (offsetHour * 60 + offsetMinute);
  }

  const milliseconds = Number(fraction.slice(0, 3).padEnd(3, "0"));
  const wallClockMs =
    dayOrdinal({ year, month, day }) * MS_PER_DAY +
    ((hour * 60 + minute) * 60 + second) * 1000 +
    milliseconds;
  const instantMs = wallClockMs - offsetMinutes * 60_000;

  return isClock(instantMs) ? instantMs : null;
};

const zoneFormatters = new Map();

const getZoneFormatter = (timeZone) => {
  if (typeof timeZone !== "string" || timeZone === "") {
    return null;
  }

  if (!zoneFormatters.has(timeZone)) {
    let formatter = null;

    try {
      formatter = new Intl.DateTimeFormat("en-US", {
        timeZone,
        calendar: "gregory",
        numberingSystem: "latn",
        year: "numeric",
        month: "numeric",
        day: "numeric",
      });
    } catch {
      formatter = null;
    }

    zoneFormatters.set(timeZone, formatter);
  }

  return zoneFormatters.get(timeZone);
};

const zoneDayOrdinal = (asOfMs, timeZone) => {
  const formatter = getZoneFormatter(timeZone);

  if (!formatter || !isClock(asOfMs)) {
    return null;
  }

  try {
    const parts = formatter.formatToParts(asOfMs);
    const part = (type) => Number(parts.find((entry) => entry.type === type)?.value);
    const date = { year: part("year"), month: part("month"), day: part("day") };

    return Object.values(date).every(Number.isInteger) ? dayOrdinal(date) : null;
  } catch {
    return null;
  }
};

/**
 * Whole calendar days from a date-only value to the calendar day containing
 * `asOfMs` in `timeZone`. Negative when the date is after that day. Returns
 * null for an invalid date, clock, or time zone.
 *
 * @param {unknown} date `YYYY-MM-DD`
 * @param {unknown} asOfMs
 * @param {unknown} timeZone IANA zone name
 * @returns {number | null}
 */
export const calendarAgeDays = (date, asOfMs, timeZone) => {
  const parsed = parseDateOnly(date);

  if (!parsed) {
    return null;
  }

  const evaluationDay = zoneDayOrdinal(asOfMs, timeZone);
  return evaluationDay === null ? null : evaluationDay - dayOrdinal(parsed);
};

const unknownEvaluation = (reason) => ({
  dataCurrency: "unknown",
  age: null,
  limit: null,
  unit: null,
  reason,
});

const isBudgetForUnit = (budget, unit) =>
  typeof budget === "object" &&
  budget !== null &&
  budget.unit === unit &&
  typeof budget.limit === "number" &&
  Number.isFinite(budget.limit) &&
  budget.limit >= 0 &&
  (unit !== "calendar_days" || Number.isInteger(budget.limit));

const isBlank = (value) =>
  value === null || value === undefined || (typeof value === "string" && value.trim() === "");

/**
 * Evaluate one observation against the caller's clock.
 *
 * Modes:
 * - `operational`: compare age with `budget` (`{ limit, unit }`, where unit is
 *   `seconds` for offset-bearing instants or `calendar_days` for date-only
 *   values in `timeZone`). Age over budget is strict: `age > limit`, compared
 *   before any display rounding (milliseconds for instants).
 * - `reviewed_snapshot`: a valid observation at or before the evaluation day
 *   is `historical`, with no budget, limit, or age.
 *
 * Observation problems are reported before budget problems, and no unknown
 * result carries an age claim.
 *
 * @param {{observedThrough?: unknown, mode?: unknown, budget?: unknown, timeZone?: unknown}} observation
 * @param {unknown} asOfMs
 * @returns {{dataCurrency: string, age: number | null, limit: number | null,
 *   unit: "seconds" | "calendar_days" | null, reason: string | null}}
 */
export const evaluateObservation = (observation, asOfMs) => {
  const { observedThrough, mode, budget, timeZone } =
    typeof observation === "object" && observation !== null ? observation : {};

  if (!isClock(asOfMs)) {
    return unknownEvaluation("invalid_clock");
  }

  if (isBlank(observedThrough)) {
    return unknownEvaluation("missing_observation");
  }

  const observedDate = parseDateOnly(observedThrough);
  const observedMs = observedDate ? null : parseInstant(observedThrough);

  if (!observedDate && observedMs === null) {
    return unknownEvaluation("invalid_observation");
  }

  let elapsed;

  if (observedDate) {
    // The date is valid and the clock is finite, so a null age means the
    // calendar zone is unusable: there is no evaluation day to compare with.
    elapsed = calendarAgeDays(observedThrough, asOfMs, timeZone);

    if (elapsed === null) {
      return unknownEvaluation("invalid_clock");
    }
  } else {
    elapsed = asOfMs - observedMs;
  }

  if (elapsed < 0) {
    return unknownEvaluation("future_observation");
  }

  if (mode === REVIEWED_SNAPSHOT) {
    return { dataCurrency: "historical", age: null, limit: null, unit: null, reason: null };
  }

  if (mode !== OPERATIONAL) {
    return unknownEvaluation("invalid_budget");
  }

  if (budget === null || budget === undefined) {
    return unknownEvaluation("missing_budget");
  }

  const unit = observedDate ? "calendar_days" : "seconds";

  if (!isBudgetForUnit(budget, unit)) {
    return unknownEvaluation("invalid_budget");
  }

  const overBudget = observedDate ? elapsed > budget.limit : elapsed > budget.limit * 1000;

  return {
    dataCurrency: overBudget ? "lagging" : "within_expected_lag",
    age: observedDate ? elapsed : elapsed / 1000,
    limit: budget.limit,
    unit,
    reason: null,
  };
};
