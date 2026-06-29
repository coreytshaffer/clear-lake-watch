const dateFormatter = new Intl.DateTimeFormat("en-US", {
  year: "numeric",
  month: "long",
  day: "numeric",
});

export const formatDate = (value) => {
  if (typeof value === "string") {
    const dateOnlyMatch = value.match(/^(\d{4})-(\d{2})-(\d{2})$/);

    if (dateOnlyMatch) {
      const [, year, month, day] = dateOnlyMatch;
      return dateFormatter.format(
        new Date(Number(year), Number(month) - 1, Number(day)),
      );
    }
  }

  return dateFormatter.format(new Date(value));
};

export const formatDateTime = (value) =>
  new Intl.DateTimeFormat("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(new Date(value));

export const daysSince = (value) => {
  const then = new Date(value).getTime();

  if (Number.isNaN(then)) {
    return null;
  }

  return Math.floor((Date.now() - then) / 86400000);
};

export const getStoredBoolean = (key, fallback = false) => {
  try {
    const value = localStorage.getItem(key);
    if (value === null) {
      return fallback;
    }

    return value === "true";
  } catch (error) {
    console.warn(error);
    return fallback;
  }
};

export const setStoredBoolean = (key, value) => {
  try {
    localStorage.setItem(key, `${value}`);
  } catch (error) {
    console.warn(error);
  }
};

export const getStoredJson = (key, fallback = null) => {
  try {
    const value = localStorage.getItem(key);

    if (value === null || value === undefined) {
      return fallback;
    }

    const parsed = JSON.parse(value);

    if (fallback === null || fallback === undefined) {
      return parsed ?? fallback;
    }

    if (Array.isArray(fallback)) {
      return Array.isArray(parsed) ? parsed : fallback;
    }

    if (typeof fallback === "object") {
      return parsed !== null && typeof parsed === "object" && !Array.isArray(parsed)
        ? parsed
        : fallback;
    }

    return typeof parsed === typeof fallback ? parsed : fallback;
  } catch (error) {
    console.warn(error);
    return fallback;
  }
};

export const setStoredJson = (key, value) => {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch (error) {
    console.warn(error);
  }
};
