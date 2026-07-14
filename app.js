import {
  daysSince,
  formatDate,
  formatDateTime,
  getStoredBoolean,
  getStoredJson,
  setStoredBoolean,
  setStoredJson,
} from "./scripts/dashboard-utils.js";

const summaryElement = document.querySelector("#summary");
const liveSummaryElement = document.querySelector("#live-summary");
const liveStatsElement = document.querySelector("#live-stats");
const trendGridElement = document.querySelector("#trend-grid");
const armSummaryElement = document.querySelector("#arm-summary");
const lakeMapElement = document.querySelector("#lake-map");
const mapDetailElement = document.querySelector("#map-detail");
const markerListElement = document.querySelector("#marker-list");
const mapAttributionElement = document.querySelector("#map-attribution");
const mapReviewFilterElement = document.querySelector("#map-review-filter");
const registrySummaryElement = document.querySelector("#registry-summary");
const mapReviewStatusElement = document.querySelector("#map-review-status");
const siteReviewGridElement = document.querySelector("#site-review-grid");
const productGridElement = document.querySelector("#product-grid");
const sourceStatusGridElement = document.querySelector("#source-status-grid");
const sourceOutputGridElement = document.querySelector("#source-output-grid");
const manifestNotesElement = document.querySelector("#manifest-notes");
const weatherContextGridElement = document.querySelector("#weather-context-grid");
const weatherContextNotesElement = document.querySelector("#weather-context-notes");
const reportTrendChartElement = document.querySelector("#report-trend-chart");
const advisoryDistributionChartElement = document.querySelector(
  "#advisory-distribution-chart"
);
const coverageGridElement = document.querySelector("#coverage-grid");
const coverageActionsElement = document.querySelector("#coverage-actions");
const recentLocationsElement = document.querySelector("#recent-locations");
const advisoryMixElement = document.querySelector("#advisory-mix");
const armGridElement = document.querySelector("#arm-grid");
const sourceGridElement = document.querySelector("#source-grid");
const moduleListElement = document.querySelector("#module-list");
const guardrailListElement = document.querySelector("#guardrail-list");
const phaseListElement = document.querySelector("#phase-list");
const mlGridElement = document.querySelector("#ml-grid");
const generatedLabelElement = document.querySelector("#generated-label");
const generatedOnElement = document.querySelector("#generated-on");
const freshnessRowElement = document.querySelector("#freshness-row");
const snapshotStatusGridElement = document.querySelector("#snapshot-status-grid");
const notificationPanelElement = document.querySelector("#notification-panel");
const notificationStatusElement = document.querySelector("#notification-status");
const notificationToggleElement = document.querySelector("#notification-toggle");
const notificationHistoryElement = document.querySelector("#notification-history");
const notificationClearHistoryElement = document.querySelector("#notification-clear-history");
const notificationResetSettingsElement = document.querySelector("#notification-reset-settings");
const notificationRuleStaleElement = document.querySelector("#notification-rule-stale");
const notificationRuleSourcesElement = document.querySelector("#notification-rule-sources");
const notificationRuleCautionElement = document.querySelector("#notification-rule-caution");
const notificationTestStaleElement = document.querySelector("#notification-test-stale");
const notificationTestSourcesElement = document.querySelector("#notification-test-sources");
const notificationTestCautionElement = document.querySelector("#notification-test-caution");
const notificationLastTestedStaleElement = document.querySelector("#notification-last-tested-stale");
const notificationLastTestedSourcesElement = document.querySelector("#notification-last-tested-sources");
const notificationLastTestedCautionElement = document.querySelector("#notification-last-tested-caution");
const liveSrSummaryElement = document.querySelector("#live-sr-summary");
const mapSrSummaryElement = document.querySelector("#map-sr-summary");
const dataProductsSrSummaryElement = document.querySelector("#data-products-sr-summary");
const analyticsSrSummaryElement = document.querySelector("#analytics-sr-summary");
const themeToggleElement = document.querySelector("#theme-toggle");
const themeColorMetaElement = document.querySelector('meta[name="theme-color"]');
const navSectionLinks = Array.from(document.querySelectorAll("[data-section-link]"));

const templates = {
  stat: document.querySelector("#stat-template"),
  arm: document.querySelector("#arm-template"),
  source: document.querySelector("#source-template"),
  simpleCard: document.querySelector("#simple-card-template"),
  phase: document.querySelector("#phase-template"),
  listItem: document.querySelector("#list-item-template"),
  trend: document.querySelector("#trend-template"),
  markerCard: document.querySelector("#marker-card-template"),
  product: document.querySelector("#product-template"),
};

const defaultMapBounds = {
  latMin: 38.9,
  latMax: 39.14,
  lonMin: -122.94,
  lonMax: -122.59,
};

let mapBounds = { ...defaultMapBounds };
let currentMapMarkers = [];
let currentMapShoreline = null;

const staleAfterDays = 7;
const notificationSettingsKey = "clearLakeNotificationsEnabled";
const notificationRuleSettingsKey = "clearLakeNotificationRules";
const notificationLastTestedKey = "clearLakeNotificationLastTested";
const notificationEventStateKey = "clearLakeNotificationEventState";
const cautionCountStateKey = "clearLakeLastCautionCount";
const notificationHistoryKey = "clearLakeNotificationHistory";
const maxNotificationHistoryItems = 5;
const themeColors = {
  light: "#f3efe2",
  dark: "#071817",
};
const fhabsReportsDatasetUrl =
  "https://lab.data.ca.gov/dataset/surface-water-freshwater-harmful-algal-blooms";

const notificationsSupported = () => "Notification" in window;

const notificationsEnabled = () =>
  notificationsSupported() &&
  getStoredBoolean(notificationSettingsKey, false) &&
  Notification.permission === "granted";

const defaultNotificationRules = {
  stale: true,
  sources: true,
  caution: true,
};

const getNotificationRules = () => {
  const storedRules = getStoredJson(notificationRuleSettingsKey, null);
  return { ...defaultNotificationRules, ...(storedRules ?? {}) };
};

const setNotificationRules = (rules) => {
  setStoredJson(notificationRuleSettingsKey, { ...defaultNotificationRules, ...rules });
};

const getNotificationLastTested = () => getStoredJson(notificationLastTestedKey, {});

const setNotificationLastTested = (value) => {
  setStoredJson(notificationLastTestedKey, value);
};

const getNotificationHistory = () => getStoredJson(notificationHistoryKey, []);

const setNotificationHistory = (historyItems) => {
  setStoredJson(notificationHistoryKey, historyItems.slice(0, maxNotificationHistoryItems));
};

const renderNotificationHistory = () => {
  if (!notificationHistoryElement) {
    return;
  }

  notificationHistoryElement.replaceChildren();
  const history = getNotificationHistory();

  if (!history.length) {
    const emptyItem = document.createElement("li");
    emptyItem.textContent = "No recent data QA notices yet.";
    notificationHistoryElement.append(emptyItem);
    return;
  }

  history.forEach((item) => {
    const entry = document.createElement("li");
    entry.textContent = `${item.timeLabel}: ${item.title}`;
    notificationHistoryElement.append(entry);
  });
};

const pushNotificationHistory = (title) => {
  const timestamp = new Date();
  const timeLabel = new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(timestamp);
  const existing = getNotificationHistory();
  const updated = [{ title, timeLabel, at: timestamp.toISOString() }, ...existing];
  setNotificationHistory(updated);
  renderNotificationHistory();
};

const updateNotificationPanel = () => {
  if (!notificationPanelElement || !notificationStatusElement || !notificationToggleElement) {
    return;
  }

  renderNotificationHistory();
  const rules = getNotificationRules();
  const lastTested = getNotificationLastTested();
  if (notificationRuleStaleElement) {
    notificationRuleStaleElement.checked = !!rules.stale;
  }
  if (notificationRuleSourcesElement) {
    notificationRuleSourcesElement.checked = !!rules.sources;
  }
  if (notificationRuleCautionElement) {
    notificationRuleCautionElement.checked = !!rules.caution;
  }
  const toDisplayTime = (value) =>
    value
      ? new Intl.DateTimeFormat("en-US", {
          month: "short",
          day: "numeric",
          hour: "numeric",
          minute: "2-digit",
        }).format(new Date(value))
      : "Never tested";
  if (notificationLastTestedStaleElement) {
    notificationLastTestedStaleElement.textContent = `Last tested: ${toDisplayTime(lastTested.stale)}`;
  }
  if (notificationLastTestedSourcesElement) {
    notificationLastTestedSourcesElement.textContent = `Last tested: ${toDisplayTime(lastTested.sources)}`;
  }
  if (notificationLastTestedCautionElement) {
    notificationLastTestedCautionElement.textContent = `Last tested: ${toDisplayTime(lastTested.caution)}`;
  }

  if (!notificationsSupported()) {
    notificationPanelElement.hidden = false;
    notificationStatusElement.textContent =
      "This browser does not support local notices for this dashboard.";
    notificationToggleElement.disabled = true;
    notificationToggleElement.textContent = "Not Supported";
    if (notificationClearHistoryElement) {
      notificationClearHistoryElement.disabled = true;
    }
    if (notificationResetSettingsElement) {
      notificationResetSettingsElement.disabled = true;
    }
    if (notificationRuleStaleElement) {
      notificationRuleStaleElement.disabled = true;
    }
    if (notificationRuleSourcesElement) {
      notificationRuleSourcesElement.disabled = true;
    }
    if (notificationRuleCautionElement) {
      notificationRuleCautionElement.disabled = true;
    }
    if (notificationTestStaleElement) {
      notificationTestStaleElement.disabled = true;
    }
    if (notificationTestSourcesElement) {
      notificationTestSourcesElement.disabled = true;
    }
    if (notificationTestCautionElement) {
      notificationTestCautionElement.disabled = true;
    }
    return;
  }

  const optedIn = getStoredBoolean(notificationSettingsKey, false);
  const permission = Notification.permission;
  notificationPanelElement.hidden = false;

  if (permission === "denied") {
    notificationStatusElement.textContent =
      "Notifications are blocked in browser settings. Enable them in site settings, then reload.";
    notificationToggleElement.disabled = true;
    notificationToggleElement.textContent = "Blocked";
    if (notificationClearHistoryElement) {
      notificationClearHistoryElement.disabled = false;
    }
    if (notificationResetSettingsElement) {
      notificationResetSettingsElement.disabled = false;
    }
    if (notificationRuleStaleElement) {
      notificationRuleStaleElement.disabled = false;
    }
    if (notificationRuleSourcesElement) {
      notificationRuleSourcesElement.disabled = false;
    }
    if (notificationRuleCautionElement) {
      notificationRuleCautionElement.disabled = false;
    }
    if (notificationTestStaleElement) {
      notificationTestStaleElement.disabled = false;
    }
    if (notificationTestSourcesElement) {
      notificationTestSourcesElement.disabled = false;
    }
    if (notificationTestCautionElement) {
      notificationTestCautionElement.disabled = false;
    }
    return;
  }

  notificationToggleElement.disabled = false;
  if (notificationClearHistoryElement) {
    notificationClearHistoryElement.disabled = false;
  }
  if (notificationResetSettingsElement) {
    notificationResetSettingsElement.disabled = false;
  }
  if (notificationRuleStaleElement) {
    notificationRuleStaleElement.disabled = false;
  }
  if (notificationRuleSourcesElement) {
    notificationRuleSourcesElement.disabled = false;
  }
  if (notificationRuleCautionElement) {
    notificationRuleCautionElement.disabled = false;
  }
  if (notificationTestStaleElement) {
    notificationTestStaleElement.disabled = false;
  }
  if (notificationTestSourcesElement) {
    notificationTestSourcesElement.disabled = false;
  }
  if (notificationTestCautionElement) {
    notificationTestCautionElement.disabled = false;
  }

  if (optedIn && permission === "granted") {
    notificationStatusElement.textContent =
      "Data QA notices are on. You can receive local notices while this app is open for stale data, source refresh issues, and FHABS caution-label count changes.";
    notificationToggleElement.textContent = "Disable Notices";
    return;
  }

  notificationStatusElement.textContent =
    "Data QA notices are off. Enable notices to receive local snapshot-change notices while this app is open.";
  notificationToggleElement.textContent = permission === "granted" ? "Enable Notices" : "Allow Notices";
};

const notify = ({ title, body, tag }) => {
  if (!notificationsEnabled()) {
    return false;
  }

  try {
    new Notification(title, {
      body,
      tag,
      renotify: false,
      silent: false,
      icon: "./assets/clear-lake-watch-icon-192.png",
      badge: "./assets/clear-lake-watch-icon-192.png",
    });
    pushNotificationHistory(title);
    return true;
  } catch (error) {
    console.warn(error);
    return false;
  }
};

const evaluateSnapshotNotifications = (liveData, manifestData) => {
  if (!notificationsEnabled() || !liveData) {
    return;
  }

  const rules = getNotificationRules();
  const generatedAt = liveData.generatedAt ?? "unknown";
  const events = getStoredJson(notificationEventStateKey, {});
  const ageDays = daysSince(liveData.generatedAt);
  const staleEventId = `stale-${generatedAt}`;

  if (rules.stale && ageDays !== null && ageDays > staleAfterDays && !events[staleEventId]) {
    notify({
      title: "Clear Lake Watch: Snapshot Freshness Notice",
      body: `The current snapshot is ${ageDays} days old.`,
      tag: "snapshot-stale",
    });
    events[staleEventId] = true;
  }

  const sourceIssues = manifestData?.sources?.filter((source) => source.status !== "ok") ?? [];
  const sourceIssueEventId = `sources-${generatedAt}-${sourceIssues.length}`;
  if (rules.sources && sourceIssues.length > 0 && !events[sourceIssueEventId]) {
    notify({
      title: "Clear Lake Watch: Source Refresh Issue Notice",
      body: `${sourceIssues.length} source feed${sourceIssues.length === 1 ? "" : "s"} need attention in the latest manifest.`,
      tag: "source-attention",
    });
    events[sourceIssueEventId] = true;
  }

  const cautionEntry = (liveData.advisoryMix ?? []).find((item) =>
    `${item.label ?? ""}`.toLowerCase().includes("caution"),
  );
  const cautionCount = Number.isFinite(cautionEntry?.count) ? cautionEntry.count : 0;
  const previousCautionCount = getStoredJson(cautionCountStateKey, null);
  if (
    rules.caution &&
    Number.isFinite(previousCautionCount) &&
    cautionCount > previousCautionCount &&
    !events[`caution-${generatedAt}`]
  ) {
    notify({
      title: "Clear Lake Watch: FHABS Caution-Label Count Changed",
      body: `Caution-labeled reports changed from ${previousCautionCount} to ${cautionCount}.`,
      tag: "caution-increase",
    });
    events[`caution-${generatedAt}`] = true;
  }

  setStoredJson(notificationEventStateKey, events);
  setStoredJson(cautionCountStateKey, cautionCount);
};

const setupNotificationControls = () => {
  if (!notificationToggleElement) {
    return;
  }

  updateNotificationPanel();

  notificationToggleElement.addEventListener("click", async () => {
    if (!notificationsSupported()) {
      return;
    }

    const currentlyEnabled = notificationsEnabled();
    if (currentlyEnabled) {
      setStoredBoolean(notificationSettingsKey, false);
      updateNotificationPanel();
      return;
    }

    if (Notification.permission === "default") {
      try {
        await Notification.requestPermission();
      } catch (error) {
        console.warn(error);
      }
    }

    if (Notification.permission === "granted") {
      setStoredBoolean(notificationSettingsKey, true);
      notify({
        title: "Clear Lake Watch Open-App Data QA Notices Enabled",
        body: "You can now receive local snapshot-change notices while this app is open.",
        tag: "alerts-enabled",
      });
    }

    updateNotificationPanel();
  });

  notificationClearHistoryElement?.addEventListener("click", () => {
    setNotificationHistory([]);
    renderNotificationHistory();
  });

  notificationResetSettingsElement?.addEventListener("click", () => {
    setStoredBoolean(notificationSettingsKey, false);
    setNotificationRules(defaultNotificationRules);
    setNotificationHistory([]);
    setNotificationLastTested({});
    setStoredJson(notificationEventStateKey, {});
    setStoredJson(cautionCountStateKey, null);
    notificationStatusElement.textContent =
      "Notification settings reset. Data QA notices are off until you enable them again.";
    updateNotificationPanel();
  });

  const updateRulesFromInputs = () => {
    setNotificationRules({
      stale: notificationRuleStaleElement?.checked ?? true,
      sources: notificationRuleSourcesElement?.checked ?? true,
      caution: notificationRuleCautionElement?.checked ?? true,
    });
    updateNotificationPanel();
  };

  notificationRuleStaleElement?.addEventListener("change", updateRulesFromInputs);
  notificationRuleSourcesElement?.addEventListener("change", updateRulesFromInputs);
  notificationRuleCautionElement?.addEventListener("change", updateRulesFromInputs);

  const runTestAlert = (ruleKey) => {
    const rules = getNotificationRules();
    const messages = {
      stale: {
        title: "Clear Lake Watch: Test Snapshot Freshness Notice",
        body: "Test only: this simulates a stale snapshot notice.",
        tag: "test-stale",
      },
      sources: {
        title: "Clear Lake Watch: Test Source Refresh Issue Notice",
        body: "Test only: this simulates a source-refresh issue notice.",
        tag: "test-sources",
      },
      caution: {
        title: "Clear Lake Watch: Test FHABS Caution-Label Count Notice",
        body: "Test only: this simulates a FHABS caution-label count-change notice.",
        tag: "test-caution",
      },
    };

    if (!rules[ruleKey]) {
      notificationStatusElement.textContent =
        "Enable this notice rule first, then test again.";
      return;
    }

    if (!notificationsEnabled()) {
      notificationStatusElement.textContent =
        "Enable notices and grant browser notification permission before sending test notices.";
      return;
    }

    const sent = notify(messages[ruleKey]);
    if (sent) {
      const current = getNotificationLastTested();
      setNotificationLastTested({ ...current, [ruleKey]: new Date().toISOString() });
    }
    updateNotificationPanel();
  };

  notificationTestStaleElement?.addEventListener("click", () => runTestAlert("stale"));
  notificationTestSourcesElement?.addEventListener("click", () => runTestAlert("sources"));
  notificationTestCautionElement?.addEventListener("click", () => runTestAlert("caution"));
};

const setSnapshotHeader = (liveData) => {
  if (!generatedLabelElement || !generatedOnElement) {
    return;
  }

  const generatedAt = liveData?.generatedAt;

  if (generatedAt && daysSince(generatedAt) !== null) {
    generatedLabelElement.textContent = "Data Refreshed";
    generatedOnElement.textContent = formatDate(generatedAt);
    generatedOnElement.classList.remove("snapshot-unavailable");
    return;
  }

  generatedLabelElement.textContent = "Snapshot Status";
    generatedOnElement.textContent = "Public snapshot unavailable";
  generatedOnElement.classList.add("snapshot-unavailable");
};

const renderScreenReaderSummaries = (liveData, manifestData, siteReviewData) => {
  if (liveSrSummaryElement) {
    const ageDays = daysSince(liveData?.generatedAt);
    const cards = liveData?.liveCards?.length ?? 0;
    liveSrSummaryElement.textContent = liveData
      ? `Public snapshot loaded with ${cards} summary cards. Snapshot age is ${
          ageDays === null ? "unknown" : `${ageDays} day${ageDays === 1 ? "" : "s"}`
        }.`
      : "Public snapshot is unavailable. Snapshot cards are not shown.";
  }

  if (mapSrSummaryElement) {
    const markerCount = liveData?.mapMarkers?.length ?? 0;
    const reviewedCount =
      liveData?.mapMarkers?.filter((marker) =>
        marker.assignmentStatus?.includes("reviewed"),
      ).length ?? 0;
    const queueCount = siteReviewData?.summary?.needsReviewCurrentMapMarkers ?? 0;
    mapSrSummaryElement.textContent = `Map section includes ${markerCount} markers. ${reviewedCount} markers are reviewed and ${queueCount} markers need local review.`;
  }

  if (dataProductsSrSummaryElement) {
    const sourceCount = manifestData?.sources?.length ?? 0;
    const sourceAttentionCount =
      manifestData?.sources?.filter((source) => source.status !== "ok").length ?? 0;
    const outputCount = manifestData?.outputs?.length ?? 0;
    dataProductsSrSummaryElement.textContent = `Data products section includes ${sourceCount} tracked sources and ${outputCount} generated outputs. ${sourceAttentionCount} sources currently need attention.`;
  }

  if (analyticsSrSummaryElement) {
    const reportYears = liveData?.analytics?.reportTrendByYear?.length ?? 0;
    const coverageSeries = liveData?.analytics?.observationCoverage?.length ?? 0;
    analyticsSrSummaryElement.textContent = `Analytics section shows ${reportYears} annual reporting trend rows and ${coverageSeries} observation coverage series summaries.`;
  }
};

const fetchJson = async (url, { optional = false } = {}) => {
  try {
    const response = await fetch(url, { cache: "no-store" });

    if (!response.ok) {
      throw new Error(`${url} returned HTTP ${response.status}`);
    }

    return await response.json();
  } catch (error) {
    if (optional) {
      console.warn(error);
      return null;
    }

    throw error;
  }
};

const createChip = (text) => {
  const chip = document.createElement("span");
  chip.className = "chip";
  chip.textContent = text;
  return chip;
};

const createSignalBadge = ({ label, kind = "context" }) => {
  const badge = document.createElement("span");
  badge.className = `signal-badge signal-${kind}`;
  badge.textContent = label;
  return badge;
};

const appendSignalBadges = (container, badges = []) => {
  if (!container || !badges.length) {
    return;
  }

  const row = document.createElement("div");
  row.className = "signal-row";
  badges.map(createSignalBadge).forEach((badge) => row.append(badge));
  container.append(row);
};

const liveStatSignalBadges = (stat) => {
  const text = `${stat.label ?? ""} ${stat.note ?? ""}`.toLowerCase();

  if (
    text.includes("lab-linked") ||
    text.includes("microscopy") ||
    text.includes("analyte")
  ) {
    return [{ label: "Observed", kind: "observed" }];
  }

  if (text.includes("fhabs") || text.includes("report")) {
    return [{ label: "Reported", kind: "reported" }];
  }

  if (text.includes("registry") || text.includes("coverage")) {
    return [
      { label: "Derived", kind: "derived" },
      { label: "Needs review", kind: "review" },
    ];
  }

  if (text.includes("forecast") || text.includes("target")) {
    return [{ label: "Experimental", kind: "experimental" }];
  }

  return [{ label: "Observed", kind: "observed" }];
};

const createSimpleCard = (title, body, badges = []) => {
  const fragment = templates.simpleCard.content.cloneNode(true);
  fragment.querySelector(".simple-title").textContent = title;
  fragment.querySelector(".simple-body").textContent = body;
  appendSignalBadges(fragment.querySelector(".simple-card"), badges);
  return fragment;
};

const createListItem = ({ title, tag, body, badges = [] }) => {
  const fragment = templates.listItem.content.cloneNode(true);
  fragment.querySelector(".list-item-title").textContent = title;
  fragment.querySelector(".list-item-tag").textContent = tag;
  fragment.querySelector(".list-item-body").textContent = body;
  appendSignalBadges(fragment.querySelector(".list-item"), badges);
  return fragment;
};

const createSvgElement = (tagName, attributes = {}) => {
  const element = document.createElementNS("http://www.w3.org/2000/svg", tagName);

  Object.entries(attributes).forEach(([key, value]) => {
    element.setAttribute(key, value);
  });

  return element;
};

const clamp = (value, min, max) => Math.min(Math.max(value, min), max);

const buildMapBounds = (shoreline, markers = []) => {
  const shorelineBounds = shoreline?.bounds;
  const markerLatitudes = markers
    .map((marker) => marker.latitude)
    .filter((value) => Number.isFinite(value));
  const markerLongitudes = markers
    .map((marker) => marker.longitude)
    .filter((value) => Number.isFinite(value));

  const latitudes = shorelineBounds
    ? [shorelineBounds.latitudeMin, shorelineBounds.latitudeMax, ...markerLatitudes]
    : markerLatitudes;
  const longitudes = shorelineBounds
    ? [shorelineBounds.longitudeMin, shorelineBounds.longitudeMax, ...markerLongitudes]
    : markerLongitudes;

  if (!latitudes.length || !longitudes.length) {
    return { ...defaultMapBounds };
  }

  const latMin = Math.min(...latitudes);
  const latMax = Math.max(...latitudes);
  const lonMin = Math.min(...longitudes);
  const lonMax = Math.max(...longitudes);
  const latPadding = Math.max((latMax - latMin) * 0.08, 0.01);
  const lonPadding = Math.max((lonMax - lonMin) * 0.08, 0.01);

  return {
    latMin: latMin - latPadding,
    latMax: latMax + latPadding,
    lonMin: lonMin - lonPadding,
    lonMax: lonMax + lonPadding,
  };
};

const projectCoordinate = ({ latitude, longitude }) => {
  const rawX =
    ((longitude - mapBounds.lonMin) / (mapBounds.lonMax - mapBounds.lonMin)) * 620 +
    30;
  const rawY =
    ((mapBounds.latMax - latitude) / (mapBounds.latMax - mapBounds.latMin)) * 460 +
    30;

  return { x: rawX, y: rawY };
};

const ringToPath = (ring) =>
  ring.points
    .map((point, index) => {
      const { x, y } = projectCoordinate(point);
      const command = index === 0 ? "M" : "L";

      return `${command} ${x.toFixed(1)} ${y.toFixed(1)}`;
    })
    .concat("Z")
    .join(" ");

const shorelineToPath = (shoreline) =>
  shoreline.rings
    .filter((ring) => ring.points?.length > 2)
    .map(ringToPath)
    .join(" ");

const drawSparkline = (svg, values) => {
  if (!values.length) {
    return;
  }

  const width = 220;
  const height = 72;
  const padding = 8;
  const numericValues = values.map((point) => point.value);
  const min = Math.min(...numericValues);
  const max = Math.max(...numericValues);
  const span = max - min || 1;

  [18, 54].forEach((y) => {
    svg.append(
      createSvgElement("line", {
        class: "sparkline-grid",
        x1: 0,
        x2: width,
        y1: y,
        y2: y,
      }),
    );
  });

  const points = values
    .map((point, index) => {
      const x =
        padding + (index / Math.max(values.length - 1, 1)) * (width - padding * 2);
      const y =
        height -
        padding -
        ((point.value - min) / span) * (height - padding * 2);

      return `${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(" ");

  svg.append(
    createSvgElement("polyline", {
      class: "sparkline-line",
      points,
    }),
  );

  const [lastX, lastY] = points.split(" ").at(-1).split(",");
  svg.append(
    createSvgElement("circle", {
      class: "sparkline-dot",
      cx: lastX,
      cy: lastY,
      r: 4,
    }),
  );
};

const renderTrendCard = (series) => {
  const fragment = templates.trend.content.cloneNode(true);
  const points = series.points ?? [];
  const latest = points.at(-1);
  const sparkline = fragment.querySelector(".sparkline");

  fragment.querySelector(".trend-title").textContent = series.label;
  fragment.querySelector(".trend-subtitle").textContent = series.station;
  sparkline.setAttribute("aria-label", `${series.label} sparkline`);
  appendSignalBadges(fragment.querySelector(".trend-card"), [
    { label: "Observed", kind: "observed" },
  ]);

  if (!latest) {
    fragment.querySelector(".trend-value").textContent = "No data";
    fragment.querySelector(".trend-note").textContent =
      "No daily observations are available for this series.";
    return fragment;
  }

  fragment.querySelector(".trend-value").textContent =
    `${latest.value.toLocaleString("en-US", { maximumFractionDigits: 2 })} ${series.unit}`;
  fragment.querySelector(".trend-note").textContent =
    `${points.length} daily observations ending ${latest.date}.`;
  sparkline.setAttribute(
    "aria-label",
    `${series.label}: ${points.length} daily observations ending ${latest.date}, latest value ${latest.value} ${series.unit}`,
  );

  drawSparkline(sparkline, points);

  return fragment;
};

const projectPoint = ({ latitude, longitude }) => {
  const { x: rawX, y: rawY } = projectCoordinate({ latitude, longitude });
  const x = clamp(rawX, 30, 650);
  const y = clamp(rawY, 30, 490);

  return { x, y, isClipped: x !== rawX || y !== rawY };
};

const markerClass = (marker) => {
  const advisory = `${marker.advisory ?? ""}`.toLowerCase();

  if (advisory.includes("caution")) {
    return "marker-caution";
  }

  if (advisory.includes("visual")) {
    return "marker-visual";
  }

  return "marker-other";
};

const formatStatusLabel = (status) => {
  if (!status) {
    return "Status unknown";
  }

  return status
    .split("-")
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(" ");
};

const matchMethodSignalBadges = (marker) => {
  const method = marker.matchMethod ?? "unknown";
  const label = `Match: ${formatStatusLabel(method)}`;
  const kind =
    method.includes("heuristic") || marker.assignmentStatus?.includes("needs")
      ? "review"
      : "derived";

  return [
    { label: "Reported", kind: "reported" },
    { label, kind },
  ];
};

const markerReviewClass = (marker) => {
  const status = marker.assignmentStatus ?? "";

  if (status.includes("reviewed")) {
    return "marker-reviewed";
  }

  if (status.includes("needs") || status.includes("unmatched")) {
    return "marker-needs-review";
  }

  return "marker-review-unknown";
};

const createSourceLink = ({ href, label, external = true }) => {
  const link = document.createElement("a");
  link.href = href;
  link.textContent = label;

  if (external) {
    link.target = "_blank";
    link.rel = "noreferrer";
  }

  return link;
};

const markerSourceLinks = (marker) => {
  const links = [
    {
      href: fhabsReportsDatasetUrl,
      label: marker.id ? `FHABS report dataset (${marker.id})` : "FHABS report dataset",
    },
  ];

  if (Number.isFinite(marker.latitude) && Number.isFinite(marker.longitude)) {
    const coordinateUrl =
      `https://www.openstreetmap.org/?mlat=${marker.latitude}&mlon=${marker.longitude}` +
      `#map=15/${marker.latitude}/${marker.longitude}`;
    links.push({
      href: coordinateUrl,
      label: "Source coordinate map",
    });
  }

  links.push({
    href: "./docs/site-registry-decision-workflow.md",
    label: "Site review workflow",
    external: false,
  });

  return links;
};

const setSelectedMarker = (
  marker,
  markerElement,
  cardElement,
  { moveFocus = false } = {},
) => {
  document
    .querySelectorAll(".map-marker.active, .marker-card.active")
    .forEach((element) => element.classList.remove("active"));

  markerElement?.classList.add("active");
  cardElement?.classList.add("active");

  const label = document.createElement("p");
  label.className = "eyebrow";
  label.textContent = "Selected Marker";

  const title = document.createElement("h3");
  title.textContent = marker.landmark;

  const advisory = document.createElement("p");
  const advisoryStrong = document.createElement("strong");
  advisoryStrong.textContent = marker.advisory;
  advisory.append(advisoryStrong, ` · ${marker.reportType}`);

  const arm = document.createElement("p");
  arm.textContent = `${marker.arm} · observed ${marker.date}`;

  const coordinates = document.createElement("p");
  coordinates.textContent = `Coordinates: ${marker.latitude.toFixed(5)}, ${marker.longitude.toFixed(5)}`;

  const match = document.createElement("p");
  const distanceText =
    marker.matchDistanceKm === null || marker.matchDistanceKm === undefined
      ? ""
      : ` Distance: ${marker.matchDistanceKm} km.`;
  match.textContent = marker.siteId
    ? `Registry match: ${marker.siteName} (${marker.siteId}) via ${marker.matchMethod}; ${marker.assignmentStatus}.${distanceText}`
    : `Registry match: none; ${marker.assignmentStatus}.`;

  const signalRow = document.createElement("div");
  signalRow.className = "signal-row";
  matchMethodSignalBadges(marker)
    .concat([{ label: formatStatusLabel(marker.assignmentStatus), kind: "review" }])
    .map(createSignalBadge)
    .forEach((badge) => signalRow.append(badge));

  const sourceLinks = document.createElement("div");
  sourceLinks.className = "map-source-links";

  const sourceLinksLabel = document.createElement("p");
  sourceLinksLabel.className = "detail-label";
  sourceLinksLabel.textContent = "Source links";

  const sourceLinkList = document.createElement("div");
  sourceLinkList.className = "map-source-link-list";
  markerSourceLinks(marker)
    .map(createSourceLink)
    .forEach((link) => sourceLinkList.append(link));
  sourceLinks.append(sourceLinksLabel, sourceLinkList);

  const sourceNote = document.createElement("p");
  sourceNote.className = "map-source-note";
  sourceNote.textContent =
    "Links support review and provenance; they do not certify local arm assignment or public-health status.";

  mapDetailElement.replaceChildren(
    label,
    title,
    signalRow,
    advisory,
    arm,
    coordinates,
    match,
    sourceLinks,
    sourceNote,
  );

  if (moveFocus) {
    mapDetailElement.focus({ preventScroll: true });
  }
};

const drawLakeBase = (shoreline = null) => {
  const title = createSvgElement("title");
  title.textContent = shoreline
    ? "Clear Lake shoreline from OpenStreetMap"
    : "Clear Lake schematic map";
  const description = createSvgElement("desc");
  description.textContent =
    shoreline
      ? "A public OpenStreetMap shoreline extract for Clear Lake with recent FHABS report markers projected from public report coordinates."
      : "A schematic map of Clear Lake with recent FHABS report markers projected from public report coordinates.";
  lakeMapElement.append(title, description);

  const lakePath = [
    "M 91 236",
    "C 98 144, 196 80, 314 98",
    "C 394 110, 452 160, 517 158",
    "C 600 156, 643 218, 601 274",
    "C 566 321, 486 304, 438 342",
    "C 379 388, 285 437, 206 397",
    "C 127 357, 83 311, 91 236",
    "Z",
  ].join(" ");

  [140, 260, 380, 500].forEach((x) => {
    lakeMapElement.append(
      createSvgElement("line", {
        class: "map-grid-line",
        x1: x,
        x2: x,
        y1: 24,
        y2: 496,
      }),
    );
  });

  [120, 240, 360].forEach((y) => {
    lakeMapElement.append(
      createSvgElement("line", {
        class: "map-grid-line",
        x1: 24,
        x2: 656,
        y1: y,
        y2: y,
      }),
    );
  });

  if (shoreline?.rings?.length) {
    lakeMapElement.append(
      createSvgElement("path", {
        class: "map-water map-water-osm",
        d: shorelineToPath(shoreline),
        "fill-rule": "evenodd",
      }),
    );
  } else {
    lakeMapElement.append(
      createSvgElement("path", {
        class: "map-water",
        d: lakePath,
      }),
    );
  }

  [
    { label: "Upper", x: 214, y: 146 },
    { label: "Lower", x: 263, y: 342 },
    { label: "Oaks", x: 519, y: 241 },
  ].forEach((arm) => {
    const text = createSvgElement("text", {
      class: "map-arm-label",
      x: arm.x,
      y: arm.y,
    });
    text.textContent = arm.label;
    lakeMapElement.append(text);
  });
};

const renderMapMarkers = (markers = [], shoreline = null) => {
  if (!lakeMapElement) {
    return;
  }

  lakeMapElement.replaceChildren();
  markerListElement.replaceChildren();
  mapBounds = buildMapBounds(shoreline, markers);
  drawLakeBase(shoreline);

  if (mapAttributionElement) {
    mapAttributionElement.replaceChildren();

    if (shoreline) {
      const sourceLink = document.createElement("a");
      sourceLink.href = shoreline.sourceUrl;
      sourceLink.target = "_blank";
      sourceLink.rel = "noreferrer";
      sourceLink.textContent = shoreline.attribution;

      const licenseLink = document.createElement("a");
      licenseLink.href = shoreline.licenseUrl;
      licenseLink.target = "_blank";
      licenseLink.rel = "noreferrer";
      licenseLink.textContent = shoreline.license;

      mapAttributionElement.append(
        "Shoreline: ",
        sourceLink,
        " · ",
        licenseLink,
      );
    } else {
      mapAttributionElement.textContent =
        "Shoreline fallback schematic; OSM geometry was not loaded.";
    }
  }

  if (!markers.length) {
    markerListElement.append(
      createListItem({
        title: "No mapped reports",
        tag: "0",
        body: "No recent FHABS reports with usable coordinates are available in this snapshot.",
        badges: [{ label: "Reported", kind: "reported" }],
      }),
    );
    return;
  }

  markers.forEach((marker, index) => {
    const { x, y, isClipped } = projectPoint(marker);
    const markerElement = createSvgElement("circle", {
      class: `map-marker ${markerClass(marker)} ${markerReviewClass(marker)}${isClipped ? " marker-clipped" : ""}`,
      cx: x.toFixed(1),
      cy: y.toFixed(1),
      r: 7,
      tabindex: 0,
      "aria-label": `${marker.landmark}, ${marker.advisory}, ${marker.date}${isClipped ? ", projected to map edge" : ""}`,
    });

    const cardFragment = templates.markerCard.content.cloneNode(true);
    const cardElement = cardFragment.querySelector(".marker-card");
    cardElement.querySelector(".marker-card-title").textContent = marker.landmark;
    cardElement.querySelector(".marker-card-meta").textContent =
      `${marker.arm} · ${marker.date} · ${marker.matchMethod}`;
    appendSignalBadges(cardElement, matchMethodSignalBadges(marker));
    const reviewBadge = document.createElement("span");
    reviewBadge.className = `review-badge ${markerReviewClass(marker)}`;
    reviewBadge.textContent = formatStatusLabel(marker.assignmentStatus);
    cardElement.append(reviewBadge);

    const selectMarker = () =>
      setSelectedMarker(marker, markerElement, cardElement, { moveFocus: true });
    markerElement.addEventListener("click", selectMarker);
    markerElement.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        selectMarker();
      }
    });
    cardElement.addEventListener("click", selectMarker);

    lakeMapElement.append(markerElement);
    markerListElement.append(cardFragment);

    if (index === 0) {
      setSelectedMarker(marker, markerElement, cardElement);
    }
  });
};

const filterMapMarkers = (markers = [], filterValue = "all") => {
  if (filterValue === "reviewed") {
    return markers.filter((marker) =>
      marker.assignmentStatus?.includes("reviewed"),
    );
  }

  if (filterValue === "needs-review") {
    return markers.filter((marker) =>
      marker.assignmentStatus?.includes("needs") ||
      marker.assignmentStatus?.includes("unmatched"),
    );
  }

  return markers;
};

const renderFilteredMapMarkers = () => {
  const filterValue = mapReviewFilterElement?.value ?? "all";
  const filteredMarkers = filterMapMarkers(currentMapMarkers, filterValue);

  renderMapMarkers(filteredMarkers, currentMapShoreline);

  if (filterValue !== "all" && !filteredMarkers.length && markerListElement) {
    markerListElement.replaceChildren(
      createListItem({
        title: "No mapped reports for this filter",
        tag: "0",
        body: "No current mapped reports match the selected review-status filter.",
        badges: [{ label: "Review filter", kind: "review" }],
      }),
    );
  }
};

const setupMapReviewFilter = () => {
  if (!mapReviewFilterElement) {
    return;
  }

  mapReviewFilterElement.addEventListener("change", renderFilteredMapMarkers);
};

const renderSiteRegistrySummary = (registry) => {
  if (!registrySummaryElement || !registry?.sites) {
    return;
  }

  const reviewedCount = registry.sites.filter((site) =>
    site.assignmentStatus?.includes("reviewed"),
  ).length;

  registrySummaryElement.textContent =
    `Starter registry: ${registry.sites.length} sites tracked, ${reviewedCount} reviewed starter assignments, ${registry.sites.length - reviewedCount} awaiting local review.`;
};

const renderCurrentMarkerReviewSummary = (markers = []) => {
  if (!registrySummaryElement || !markers.length) {
    return;
  }

  const needsReviewCount = markers.filter((marker) =>
    marker.assignmentStatus?.includes("needs") ||
    marker.assignmentStatus?.includes("unmatched"),
  ).length;
  const reviewedCount = markers.filter((marker) =>
    marker.assignmentStatus?.includes("reviewed"),
  ).length;

  registrySummaryElement.textContent = `${registrySummaryElement.textContent} Current mapped reports: ${reviewedCount} reviewed, ${needsReviewCount} needing local review.`;

  if (mapReviewStatusElement) {
    mapReviewStatusElement.textContent =
      needsReviewCount > 0
        ? `Map review status: ${needsReviewCount} current FHABS marker${needsReviewCount === 1 ? "" : "s"} still need local review before site or arm assignments should be treated as authoritative.`
        : "Map review status: current markers have reviewed site and arm assignments.";
  }
};

const renderSiteReviewSummary = (siteReviewData) => {
  if (!siteReviewGridElement) {
    return;
  }

  siteReviewGridElement.replaceChildren();

  if (!siteReviewData?.summary) {
    const empty = document.createElement("p");
    empty.className = "empty-state";
    empty.textContent =
      "The site-review summary is unavailable, so marker QA status cannot be shown.";
    siteReviewGridElement.append(empty);
    return;
  }

  const { summary } = siteReviewData;
  const reviewCards = [
    {
      label: "Registry sites",
      value: summary.registrySites,
      note: `${summary.reviewedRegistrySites} reviewed starters; ${summary.needsReviewRegistrySites} need local review.`,
      badges: [
        { label: "Registry", kind: "derived" },
        { label: "Review needed", kind: "review" },
      ],
    },
    {
      label: "Current map markers",
      value: summary.currentMapMarkers,
      note: "Recent FHABS report markers included in the current public snapshot.",
      badges: [
        { label: "Reported", kind: "reported" },
        { label: "Mapped", kind: "derived" },
      ],
    },
    {
      label: "Reviewed markers",
      value: summary.reviewedCurrentMapMarkers,
      note: "Current mapped reports with reviewed arm/site assignment status.",
      badges: [{ label: "Reviewed", kind: "observed" }],
    },
    {
      label: "Needs local review",
      value: summary.needsReviewCurrentMapMarkers,
      note: "Current mapped reports that should not be treated as locally certified.",
      badges: [{ label: "Needs review", kind: "review" }],
    },
    {
      label: "High-priority checks",
      value: summary.highPriorityReviewItems,
      note: "Review these site-registry matches first because they affect public map trust cues.",
      badges: [{ label: "QA priority", kind: "review" }],
    },
  ];

  reviewCards.forEach((card) => {
    const article = document.createElement("article");
    article.className = "review-summary-card";

    const label = document.createElement("p");
    label.className = "stat-label";
    label.textContent = card.label;

    const value = document.createElement("strong");
    value.className = "stat-value";
    value.textContent = `${card.value ?? 0}`;

    const note = document.createElement("p");
    note.className = "stat-note";
    note.textContent = card.note;

    article.append(label, value, note);
    appendSignalBadges(article, card.badges);
    siteReviewGridElement.append(article);
  });
};

const renderWeatherContext = (weatherContext) => {
  if (!weatherContextGridElement && !weatherContextNotesElement) {
    return;
  }

  weatherContextGridElement?.replaceChildren();
  weatherContextNotesElement?.replaceChildren();

  if (!weatherContext) {
    const card = document.createElement("article");
    card.className = "weather-context-card weather-context-unavailable";

    const title = document.createElement("h3");
    title.textContent = "Weather backbone not connected yet";

    const body = document.createElement("p");
    body.textContent =
      "No public weather-context.json export is present. The lake dashboard is running from public lake-source snapshots only.";

    card.append(title, body);
    appendSignalBadges(card, [
      { label: "Context layer", kind: "context" },
      { label: "Not live", kind: "review" },
    ]);
    weatherContextGridElement?.append(card);
    return;
  }

  const statusCard = document.createElement("article");
  statusCard.className = "weather-context-card";

  const title = document.createElement("h3");
  title.textContent = weatherContext.sourceName ?? "Weather context export";

  const status = document.createElement("p");
  status.textContent =
    `Status: ${formatStatusLabel(weatherContext.machineReadableStatus ?? "unknown")}`;

  const generatedAt = document.createElement("p");
  generatedAt.textContent = weatherContext.generatedAt
    ? `Generated: ${formatDateTime(weatherContext.generatedAt)}`
    : "Generated: unavailable";

  statusCard.append(title, status, generatedAt);
  appendSignalBadges(statusCard, [
    { label: "Weather context", kind: "context" },
    { label: "Separate domain", kind: "review" },
  ]);
  weatherContextGridElement?.append(statusCard);

  weatherContext.summaryCards?.forEach((summary) => {
    const card = document.createElement("article");
    card.className = "weather-context-card";

    const summaryTitle = document.createElement("p");
    summaryTitle.className = "stat-label";
    summaryTitle.textContent = summary.label;

    const value = document.createElement("strong");
    value.className = "stat-value";
    value.textContent = summary.value;

    const note = document.createElement("p");
    note.className = "stat-note";
    note.textContent = summary.note;

    card.append(summaryTitle, value, note);
    appendSignalBadges(card, [{ label: "Context only", kind: "context" }]);
    weatherContextGridElement?.append(card);
  });

  weatherContext.qualityNotes?.forEach((note) => {
    const item = document.createElement("p");
    item.textContent = note;
    weatherContextNotesElement?.append(item);
  });
};

const renderDataProducts = (products = []) => {
  if (!productGridElement) {
    return;
  }

  productGridElement.replaceChildren();

  products.forEach((product) => {
    const fragment = templates.product.content.cloneNode(true);
    fragment.querySelector(".product-name").textContent = product.name;
    const recordCount = Number.isFinite(product.recordCount) ? product.recordCount : 0;
    fragment.querySelector(".product-count").textContent =
      `${recordCount.toLocaleString("en-US")} records`;
    fragment.querySelector(".product-description").textContent = product.description;
    appendSignalBadges(fragment.querySelector(".product-card"), [
      { label: "Export", kind: "export" },
      { label: "Source-backed", kind: "context" },
    ]);

    const link = fragment.querySelector(".product-link");
    link.href = product.file;

    productGridElement.append(fragment);
  });
};

const renderSourceStatus = (manifestData) => {
  if (!sourceStatusGridElement && !sourceOutputGridElement && !manifestNotesElement) {
    return;
  }

  sourceStatusGridElement?.replaceChildren();
  sourceOutputGridElement?.replaceChildren();
  manifestNotesElement?.replaceChildren();

  if (!manifestData?.sources?.length) {
    const empty = document.createElement("p");
    empty.className = "empty-state";
    empty.textContent =
      "The snapshot manifest is unavailable, so source refresh status cannot be shown.";
    sourceStatusGridElement?.append(empty);
    return;
  }

  manifestData.sources.forEach((source) => {
    const card = document.createElement("article");
    const status = source.status ?? "unknown";
    card.className = `source-status-card source-status-${status}`;

    const title = document.createElement("h4");
    title.textContent = source.label;

    const statusBadge = createSignalBadge({
      label: status === "ok" ? "Source loaded" : "Source attention",
      kind: status === "ok" ? "observed" : "review",
    });

    const meta = document.createElement("p");
    meta.className = "source-status-meta";
    const clearLakeRows = source.clearLakeRowCount ?? null;
    const sourceRows = Number.isFinite(source.rowCount) ? source.rowCount : 0;
    const rowText =
      clearLakeRows === null
        ? `${sourceRows.toLocaleString("en-US")} rows`
        : `${clearLakeRows.toLocaleString("en-US")} Clear Lake rows / ${sourceRows.toLocaleString("en-US")} source rows`;
    meta.textContent = `${source.source}: ${rowText}`;

    const date = document.createElement("p");
    date.className = "source-status-date";
    date.textContent = source.latestObservationDate
      ? `Latest observation: ${formatDate(source.latestObservationDate)}`
      : "Latest observation: unavailable";

    const freshness = document.createElement("p");
    freshness.className = "source-status-note";
    freshness.textContent =
      source.resourceAgeDays === null || source.resourceAgeDays === undefined
        ? source.note
        : `Resource file age: ${source.resourceAgeDays} days. ${source.note}`;

    card.append(title, statusBadge, meta, date, freshness);
    sourceStatusGridElement?.append(card);
  });

  manifestData.outputs?.forEach((output) => {
    const card = document.createElement("article");
    card.className = "source-output-card";

    const title = document.createElement("h4");
    title.textContent = output.file;

    const count = document.createElement("p");
    count.className = "source-status-meta";
    count.textContent =
      `${(output.recordCount ?? 0).toLocaleString("en-US")} records`;

    const description = document.createElement("p");
    description.className = "source-status-note";
    description.textContent = output.description;

    card.append(title, count, description);
    sourceOutputGridElement?.append(card);
  });

  manifestData.notes?.forEach((note) => {
    const item = document.createElement("p");
    item.textContent = note;
    manifestNotesElement?.append(item);
  });
};

const findManifestSource = (manifestData, sourceId) =>
  manifestData?.sources?.find((source) => source.id === sourceId);

const createSnapshotStatusCard = ({ label, value, note, kind = "derived" }) => {
  const article = document.createElement("article");
  article.className = "snapshot-status-card";

  const labelElement = document.createElement("p");
  labelElement.className = "stat-label";
  labelElement.textContent = label;

  const valueElement = document.createElement("strong");
  valueElement.className = "snapshot-status-value";
  valueElement.textContent = value;

  const noteElement = document.createElement("p");
  noteElement.className = "stat-note";
  noteElement.textContent = note;

  article.append(labelElement, valueElement, noteElement);
  appendSignalBadges(article, [{ label: "Snapshot context", kind }]);
  return article;
};

const renderSnapshotStatusStrip = (manifestData) => {
  if (!snapshotStatusGridElement) {
    return;
  }

  snapshotStatusGridElement.replaceChildren();

  if (!manifestData) {
    const empty = document.createElement("p");
    empty.className = "empty-state";
    empty.textContent =
      "Snapshot status is unavailable because the public manifest could not be loaded.";
    snapshotStatusGridElement.append(empty);
    return;
  }

  const usgsLevel = findManifestSource(manifestData, "usgs-lake-level");
  const usgsFlow = findManifestSource(manifestData, "usgs-cole-creek-discharge");
  const fhabsReports = findManifestSource(manifestData, "fhabs-bloom-reports");
  const fhabsResults = findManifestSource(manifestData, "fhabs-results");
  const usgsDates = [usgsLevel, usgsFlow]
    .map((source) => source?.latestObservationDate)
    .filter(Boolean)
    .sort();
  const latestUsgsDate = usgsDates.at(-1);

  const cards = [
    {
      label: "Snapshot generated",
      value: manifestData.generatedAt
        ? formatDateTime(manifestData.generatedAt)
        : "Unavailable",
      note: "Dashboard files are generated snapshots, not live sensor telemetry.",
      kind: "derived",
    },
    {
      label: "USGS observations through",
      value: latestUsgsDate ? formatDate(latestUsgsDate) : "Unavailable",
      note: "Hydrology dates can be newer than bloom-report or lab-result dates.",
      kind: "observed",
    },
    {
      label: "Latest Clear Lake FHABS report",
      value: fhabsReports?.latestObservationDate
        ? formatDate(fhabsReports.latestObservationDate)
        : "Unavailable",
      note: "Report dates reflect what is present in the public FHABS source file.",
      kind: "reported",
    },
    {
      label: "Latest FHABS lab-linked sample",
      value: fhabsResults?.latestObservationDate
        ? formatDate(fhabsResults.latestObservationDate)
        : "Unavailable",
      note: "Lab-linked result records may lag the public report stream.",
      kind: "reported",
    },
    {
      label: "Use boundary",
      value: "Research and situational awareness only",
      note: "Not recreation guidance, emergency guidance, or public-health guidance.",
      kind: "review",
    },
  ];

  cards.forEach((card) => {
    snapshotStatusGridElement.append(createSnapshotStatusCard(card));
  });
};

const renderFreshnessBadge = (generatedAt, { unavailable = false } = {}) => {
  if (!freshnessRowElement) {
    return;
  }

  freshnessRowElement.replaceChildren();

  const ageDays = daysSince(generatedAt);
  const badge = document.createElement("span");
  badge.className = "freshness-badge";

  if (unavailable) {
    badge.classList.add("freshness-unavailable");
    badge.textContent = "Public snapshot unavailable";
  } else if (ageDays === null) {
    badge.classList.add("freshness-unknown");
    badge.textContent = "Snapshot freshness unknown";
  } else if (ageDays > staleAfterDays) {
    badge.classList.add("freshness-stale");
    badge.textContent = `Snapshot is ${ageDays} days old`;
  } else {
    badge.classList.add("freshness-current");
    badge.textContent = ageDays === 0 ? "Snapshot refreshed today" : `Snapshot refreshed ${ageDays} days ago`;
  }

  const note = document.createElement("span");
  note.className = "freshness-note";
  note.textContent = unavailable
    ? "The public data bundle could not be loaded, so snapshot values are not being shown."
    : "Source observation dates may be older than the dashboard refresh time.";

  freshnessRowElement.append(badge, note);
};

const createBarRow = ({ label, value, max }) => {
  const safeValue = Number.isFinite(value) ? value : 0;
  const safeMax = Number.isFinite(max) ? Math.max(max, 1) : 1;
  const row = document.createElement("div");
  row.className = "bar-row";

  const labelElement = document.createElement("span");
  labelElement.className = "bar-label";
  labelElement.textContent = label;

  const track = document.createElement("span");
  track.className = "bar-track";

  const fill = document.createElement("span");
  fill.className = "bar-fill";
  fill.style.width = `${Math.max((safeValue / safeMax) * 100, 2)}%`;
  track.append(fill);

  const valueElement = document.createElement("span");
  valueElement.className = "bar-value";
  valueElement.textContent = safeValue.toLocaleString("en-US");

  row.append(labelElement, track, valueElement);
  return row;
};

const renderCoverageItems = (coverageItems, { showAll = false } = {}) => {
  if (!coverageGridElement) {
    return;
  }

  coverageGridElement.replaceChildren();
  coverageActionsElement?.replaceChildren();

  const visibleItems = showAll ? coverageItems : coverageItems.slice(0, 6);

  visibleItems.forEach((coverage) => {
    const item = document.createElement("article");
    item.className = "coverage-item";

    const title = document.createElement("strong");
    title.textContent = coverage.parameterName || "Unspecified parameter";

    const meta = document.createElement("span");
    meta.textContent = `${coverage.source} · ${coverage.siteName} · ${coverage.count} observations`;

    const dates = document.createElement("span");
    dates.textContent = `${coverage.firstObservedDate || "Unknown"} to ${coverage.lastObservedDate || "Unknown"}`;

    item.append(title, meta, dates);
    appendSignalBadges(item, [
      { label: "Observed", kind: "observed" },
      { label: "Coverage summary", kind: "derived" },
    ]);
    coverageGridElement.append(item);
  });

  if (coverageItems.length <= 6 || !coverageActionsElement) {
    return;
  }

  const toggle = document.createElement("button");
  toggle.className = "button button-secondary coverage-toggle";
  toggle.type = "button";
  toggle.textContent = showAll
    ? "Show Fewer Series"
    : `Show All ${coverageItems.length} Series`;
  toggle.addEventListener("click", () => {
    renderCoverageItems(coverageItems, { showAll: !showAll });
  });

  coverageActionsElement.append(toggle);
};

const renderAnalytics = (analytics) => {
  if (!reportTrendChartElement && !advisoryDistributionChartElement && !coverageGridElement) {
    return;
  }

  reportTrendChartElement?.replaceChildren();
  advisoryDistributionChartElement?.replaceChildren();
  coverageGridElement?.replaceChildren();
  coverageActionsElement?.replaceChildren();

  if (!analytics) {
    return;
  }

  const yearlyMax = Math.max(
    ...analytics.reportTrendByYear.map((year) => year.total),
    1,
  );

  analytics.reportTrendByYear.forEach((year) => {
    reportTrendChartElement?.append(
      createBarRow({
        label: `${year.year}`,
        value: year.total,
        max: yearlyMax,
      }),
    );
  });

  analytics.advisoryDistributionByArm
    .filter((arm) => arm.total > 0)
    .forEach((arm) => {
      const section = document.createElement("div");
      section.className = "arm-category";

      const title = document.createElement("p");
      title.className = "arm-category-title";
      title.textContent = `${arm.arm} (${arm.total} reported records)`;
      section.append(title);

      const maxCategory = Math.max(
        ...arm.categories.map((category) => category.count),
        1,
      );

      arm.categories.slice(0, 3).forEach((category) => {
        section.append(
          createBarRow({
            label: category.label,
            value: category.count,
            max: maxCategory,
          }),
        );
      });

      advisoryDistributionChartElement?.append(section);
    });

  renderCoverageItems(analytics.observationCoverage ?? []);
};

const renderStats = (data) => {
  if (!summaryElement || !templates.stat || !data?.sources) {
    return;
  }

  summaryElement.replaceChildren();

  const historicalSpan = data.sources
    .map((source) => source.historicalStartYear)
    .filter(Boolean)
    .sort()[0];

  const statCards = [
    {
      label: "Verified public feeds",
      value: `${data.sources.length}`,
      note: "Core source families relevant to an initial public release.",
      badges: [{ label: "Public source", kind: "context" }],
    },
    {
      label: "Lake arms in scope",
      value: `${data.arms.length}`,
      note: "Upper, Lower, and Oaks arms modeled as distinct monitoring zones.",
      badges: [{ label: "Derived zones", kind: "derived" }],
    },
    {
      label: "Historical reach",
      value: historicalSpan ? `${historicalSpan}+` : "Mixed",
      note: "Earliest public monitoring history represented in the current plan.",
      badges: [{ label: "Derived", kind: "derived" }],
    },
    {
      label: "Automated public feeds",
      value: "2",
      note: "USGS hydrology and FHABS reports currently populate the public snapshot; other source families remain planned, manual, or review-gated.",
      badges: [{ label: "Implemented feeds", kind: "observed" }],
    },
  ];

  statCards.forEach((stat) => {
    const fragment = templates.stat.content.cloneNode(true);
    fragment.querySelector(".stat-label").textContent = stat.label;
    fragment.querySelector(".stat-value").textContent = stat.value;
    fragment.querySelector(".stat-note").textContent = stat.note;
    appendSignalBadges(fragment.querySelector(".stat-card"), stat.badges);
    summaryElement.append(fragment);
  });
};

const renderLiveSnapshot = (liveData, shorelineData = null, siteReviewData = null) => {
  if (!liveStatsElement && !trendGridElement && !armSummaryElement && !lakeMapElement) {
    return;
  }

  liveStatsElement?.replaceChildren();
  trendGridElement?.replaceChildren();
  armSummaryElement?.replaceChildren();
  recentLocationsElement?.replaceChildren();
  advisoryMixElement?.replaceChildren();

  if (!liveData) {
    renderFreshnessBadge(null, { unavailable: true });
    if (liveSummaryElement) {
      liveSummaryElement.textContent =
        "The public snapshot could not be loaded. Snapshot cards are unavailable until the public data bundle loads successfully.";
    }
    renderDataProducts([]);
    renderAnalytics(null);
    currentMapMarkers = [];
    currentMapShoreline = shorelineData;
    renderFilteredMapMarkers();
    return;
  }

  renderFreshnessBadge(liveData.generatedAt);

  if (liveSummaryElement) {
    liveSummaryElement.textContent = `Last refreshed ${formatDateTime(
      liveData.generatedAt,
    )}. Dates shown below are observation dates from the source systems.`;
  }

  liveData.liveCards?.forEach((stat) => {
    const fragment = templates.stat.content.cloneNode(true);
    fragment.querySelector(".stat-label").textContent = stat.label;
    fragment.querySelector(".stat-value").textContent = stat.value;
    fragment.querySelector(".stat-note").textContent = stat.note;
    appendSignalBadges(fragment.querySelector(".stat-card"), liveStatSignalBadges(stat));
    liveStatsElement?.append(fragment);
  });

  liveData.hydrologySeries?.forEach((series) => {
    trendGridElement?.append(renderTrendCard(series));
  });

  liveData.armSummaries?.forEach((item) => {
    armSummaryElement?.append(
      createListItem({
        title: item.arm,
        tag: `${item.reportCount}`,
        body: item.latest
          ? `${item.latest.advisory} · latest report ${item.latest.date} at ${item.latest.landmark}`
          : "No recent FHABS reports grouped to this arm in the snapshot.",
        badges: [
          { label: "Derived", kind: "derived" },
          { label: "Reported inputs", kind: "reported" },
        ],
      }),
    );
  });

  renderCurrentMarkerReviewSummary(liveData.mapMarkers);
  renderSiteReviewSummary(siteReviewData);
  currentMapMarkers = liveData.mapMarkers ?? [];
  currentMapShoreline = shorelineData;
  renderFilteredMapMarkers();

  const dataProducts = [...(liveData.dataProducts ?? [])];
  if (shorelineData) {
    const shorelinePointCount = shorelineData.rings.reduce(
      (total, ring) => total + ring.pointCount,
      0,
    );
    dataProducts.push({
      name: "Lake shoreline geometry",
      file: "data/lake-shoreline.json",
      recordCount: shorelinePointCount,
      description:
        "OpenStreetMap-derived Clear Lake multipolygon rings used to render the public shoreline overlay.",
    });
  }
  if (siteReviewData) {
    dataProducts.push({
      name: "Site review queue",
      file: "data/site-review-summary.json",
      recordCount: siteReviewData.summary?.needsReviewCurrentMapMarkers ?? 0,
      description:
        "Sanitized aggregate QA summary for stable site IDs, arm assignments, and current mapped reports needing local review.",
    });
  }
  renderDataProducts(dataProducts);
  renderAnalytics(liveData.analytics);

  liveData.recentLocations?.forEach((item) => {
    recentLocationsElement?.append(
      createListItem({
        title: item.landmark,
        tag: item.date,
        body: `${item.advisory} · ${item.reportType}`,
        badges: [{ label: "Reported", kind: "reported" }],
      }),
    );
  });

  liveData.advisoryMix?.forEach((item) => {
    advisoryMixElement?.append(
      createListItem({
        title: item.label,
        tag: `${item.count}`,
        body: item.note,
        badges: [
          { label: "Derived", kind: "derived" },
          { label: "Reporting pattern", kind: "review" },
        ],
      }),
    );
  });
};

const renderArms = (arms) => {
  if (!armGridElement || !templates.arm) {
    return;
  }

  armGridElement.replaceChildren();

  arms.forEach((arm) => {
    const fragment = templates.arm.content.cloneNode(true);
    fragment.querySelector(".arm-name").textContent = arm.name;
    fragment.querySelector(".arm-badge").textContent = arm.monitoringProfile;
    fragment.querySelector(".arm-summary").textContent = arm.summary;
    appendSignalBadges(fragment.querySelector(".arm-card"), [
      { label: "Derived zone", kind: "derived" },
      { label: "Planning context", kind: "planning" },
    ]);

    const focusContainer = fragment.querySelector(".arm-focus");
    arm.focus.map(createChip).forEach((chip) => focusContainer.append(chip));

    const signalsContainer = fragment.querySelector(".arm-signals");
    arm.primarySignals
      .map(createChip)
      .forEach((chip) => signalsContainer.append(chip));

    const questionsContainer = fragment.querySelector(".arm-questions");
    arm.priorityQuestions.forEach((question) => {
      const item = document.createElement("li");
      item.textContent = question;
      questionsContainer.append(item);
    });

    armGridElement.append(fragment);
  });
};

const renderSources = (sources) => {
  if (!sourceGridElement || !templates.source) {
    return;
  }

  sourceGridElement.replaceChildren();

  sources.forEach((source) => {
    const fragment = templates.source.content.cloneNode(true);
    fragment.querySelector(".source-name").textContent = source.name;
    fragment.querySelector(".source-owner").textContent = source.owner;
    fragment.querySelector(".source-status").textContent = source.machineReadableStatus;
    fragment.querySelector(".source-summary").textContent = source.summary;
    fragment.querySelector(".source-cadence").textContent = source.cadence;
    fragment.querySelector(".source-coverage").textContent = source.coverage;
    fragment.querySelector(".source-usage").textContent = source.mvpUsage;
    fragment.querySelector(".source-automation").textContent = source.automationNote;
    appendSignalBadges(fragment.querySelector(".source-card"), [
      { label: "Public source", kind: "context" },
      { label: source.machineReadableStatus, kind: "derived" },
    ]);

    const link = fragment.querySelector(".source-link");
    link.href = source.url;

    sourceGridElement.append(fragment);
  });
};

const renderSimpleSection = (items, parent, badges = []) => {
  if (!parent) {
    return;
  }

  parent.replaceChildren();

  items.forEach((item) => {
    parent.append(createSimpleCard(item.title, item.body, badges));
  });
};

const renderPhases = (phases) => {
  if (!phaseListElement || !templates.phase) {
    return;
  }

  phaseListElement.replaceChildren();

  phases.forEach((phase) => {
    const fragment = templates.phase.content.cloneNode(true);
    fragment.querySelector(".phase-name").textContent = phase.name;
    fragment.querySelector(".phase-window").textContent = phase.window;
    fragment.querySelector(".phase-goal").textContent = phase.goal;
    appendSignalBadges(fragment.querySelector(".phase-card"), [
      { label: "Planning", kind: "planning" },
    ]);

    const list = fragment.querySelector(".phase-deliverables");
    phase.deliverables.forEach((deliverable) => {
      const item = document.createElement("li");
      item.textContent = deliverable;
      list.append(item);
    });

    phaseListElement.append(fragment);
  });
};

const renderMlCards = (mlRoadmap) => {
  if (!mlGridElement) {
    return;
  }

  mlGridElement.replaceChildren();

  mlRoadmap.forEach((item) => {
    mlGridElement.append(
      createSimpleCard(item.title, item.body, [
        { label: "Experimental", kind: "experimental" },
        { label: "Not live guidance", kind: "review" },
      ]),
    );
  });
};

const setTheme = (theme) => {
  document.documentElement.dataset.theme = theme;
  themeToggleElement?.setAttribute("aria-pressed", `${theme === "dark"}`);
  themeColorMetaElement?.setAttribute("content", themeColors[theme] ?? themeColors.light);

  if (themeToggleElement) {
    themeToggleElement.textContent = theme === "dark" ? "Light Mode" : "Dark Mode";
  }

  try {
    localStorage.setItem("clearLakeTheme", theme);
  } catch (error) {
    console.warn(error);
  }
};

const setupThemeToggle = () => {
  let savedTheme = null;

  try {
    savedTheme = localStorage.getItem("clearLakeTheme");
  } catch (error) {
    console.warn(error);
  }

  const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
  setTheme(savedTheme ?? (prefersDark ? "dark" : "light"));

  themeToggleElement?.addEventListener("click", () => {
    setTheme(document.documentElement.dataset.theme === "dark" ? "light" : "dark");
  });
};

const setupActiveNavigation = () => {
  if (!navSectionLinks.length || !("IntersectionObserver" in window)) {
    return;
  }

  const linkBySection = new Map(
    navSectionLinks.map((link) => [link.dataset.sectionLink, link]),
  );
  const setActiveLink = (sectionId) => {
    navSectionLinks.forEach((link) => link.removeAttribute("aria-current"));
    linkBySection.get(sectionId)?.setAttribute("aria-current", "true");
  };
  const initialSection = window.location.hash.replace("#", "") || "live";
  setActiveLink(initialSection);

  const observer = new IntersectionObserver(
    (entries) => {
      const activeEntry = entries
        .filter((entry) => entry.isIntersecting)
        .sort((first, second) => second.intersectionRatio - first.intersectionRatio)
        .at(0);

      if (!activeEntry) {
        return;
      }

      setActiveLink(activeEntry.target.id);
    },
    {
      rootMargin: "-25% 0px -55% 0px",
      threshold: [0.2, 0.4, 0.6],
    },
  );

  linkBySection.forEach((link, sectionId) => {
    const section = document.getElementById(sectionId);

    if (section) {
      observer.observe(section);
    }
  });

  window.addEventListener("hashchange", () => {
    const sectionId = window.location.hash.replace("#", "");

    if (sectionId) {
      setActiveLink(sectionId);
    }
  });
};

const registerServiceWorker = () => {
  if (!("serviceWorker" in navigator)) {
    return;
  }

  window.addEventListener("load", () => {
    navigator.serviceWorker.register("./sw.js").catch((error) => {
      console.warn(error);
    });
  });
};

const boot = async () => {
  setupThemeToggle();
  setupActiveNavigation();
  setupMapReviewFilter();
  setupNotificationControls();
  registerServiceWorker();

  const [
    data,
    liveData,
    sitesData,
    shorelineData,
    siteReviewData,
    manifestData,
    weatherContextData,
  ] = await Promise.all([
    fetchJson("./data/sources.json"),
    fetchJson("./data/live.json", { optional: true }),
    fetchJson("./data/sites.json", { optional: true }),
    fetchJson("./data/lake-shoreline.json", { optional: true }),
    fetchJson("./data/site-review-summary.json", { optional: true }),
    fetchJson("./data/manifest.json", { optional: true }),
    fetchJson("./data/weather-context.json", { optional: true }),
  ]);

  setSnapshotHeader(liveData);

  renderSiteRegistrySummary(sitesData);
  renderLiveSnapshot(liveData, shorelineData, siteReviewData);
  renderSourceStatus(manifestData);
  renderSnapshotStatusStrip(manifestData);
  evaluateSnapshotNotifications(liveData, manifestData);
  updateNotificationPanel();
  renderScreenReaderSummaries(liveData, manifestData, siteReviewData);
  renderWeatherContext(weatherContextData);
  renderStats(data);
  renderArms(data.arms);
  renderSources(data.sources);
  renderSimpleSection(data.modules, moduleListElement, [
    { label: "Planning", kind: "planning" },
  ]);
  renderSimpleSection(data.guardrails, guardrailListElement, [
    { label: "Guardrail", kind: "review" },
  ]);
  renderPhases(data.phases);
  renderMlCards(data.mlRoadmap);
};

boot().catch((error) => {
  setSnapshotHeader(null);
  renderFreshnessBadge(null, { unavailable: true });
  const fallback = document.createElement("p");
  fallback.textContent =
    "The prototype data file could not be loaded. Check app.js and data/sources.json.";
  fallback.className = "error-message";
  summaryElement?.append(fallback);
  renderScreenReaderSummaries(null, null, null);
  console.error(error);
});
