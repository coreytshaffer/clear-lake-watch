import { daysSince } from '../scripts/dashboard-utils.js';

const resultsList = document.getElementById('test-results');
const summaryDiv = document.getElementById('summary');

let passCount = 0;
let failCount = 0;

function assert(condition, message) {
  if (!condition) {
    throw new Error(message || 'Assertion failed');
  }
}

function assertEquals(actual, expected, message) {
  if (actual !== expected) {
    throw new Error(`${message || 'Assertion failed'}: expected ${expected}, but got ${actual}`);
  }
}

function runTest(name, testFn) {
  const li = document.createElement('li');
  li.className = 'test-result';

  try {
    testFn();
    li.classList.add('test-pass');
    li.textContent = `✅ PASS: ${name}`;
    console.log(`✅ PASS: ${name}`);
    passCount++;
  } catch (error) {
    li.classList.add('test-fail');
    li.innerHTML = `❌ FAIL: ${name}<div class="error-details">${error.message}</div>`;
    console.error(`❌ FAIL: ${name}`, error);
    failCount++;
  }

  resultsList.appendChild(li);
}

function updateSummary() {
  const total = passCount + failCount;
  summaryDiv.innerHTML = `<strong>Results:</strong> ${passCount} passed, ${failCount} failed, ${total} total.`;
  summaryDiv.style.color = failCount > 0 ? '#cf222e' : '#2ea043';
}

// Store original Date.now
const originalDateNow = Date.now;

// Helper to mock time for a specific test block
function withMockedTime(mockTimestamp, testFn) {
  try {
    Date.now = () => mockTimestamp;
    testFn();
  } finally {
    // Always restore the original Date.now
    Date.now = originalDateNow;
  }
}

// Test Suite
console.log('Running tests...');

// Base reference time for testing: 2024-01-15T12:00:00.000Z
const MOCK_NOW = new Date('2024-01-15T12:00:00.000Z').getTime();
const ONE_DAY_MS = 86400000;

runTest('invalid date string returns null', () => {
  withMockedTime(MOCK_NOW, () => {
    assertEquals(daysSince('invalid-date'), null, 'Expected invalid date to return null');
    assertEquals(daysSince(''), null, 'Expected empty string to return null');
  });
});

runTest('same timestamp returns 0', () => {
  withMockedTime(MOCK_NOW, () => {
    assertEquals(daysSince(MOCK_NOW), 0, 'Expected same timestamp to return 0');
    assertEquals(daysSince(new Date(MOCK_NOW).toISOString()), 0, 'Expected same ISO date to return 0');
  });
});

runTest('exactly one day ago returns 1', () => {
  withMockedTime(MOCK_NOW, () => {
    const oneDayAgo = MOCK_NOW - ONE_DAY_MS;
    assertEquals(daysSince(oneDayAgo), 1, 'Expected one day ago numeric timestamp to return 1');
    assertEquals(daysSince(new Date(oneDayAgo).toISOString()), 1, 'Expected one day ago ISO date to return 1');
  });
});

runTest('fractional day differences are floored', () => {
  withMockedTime(MOCK_NOW, () => {
    // 1.5 days ago
    const oneAndHalfDaysAgo = MOCK_NOW - (ONE_DAY_MS * 1.5);
    assertEquals(daysSince(oneAndHalfDaysAgo), 1, 'Expected 1.5 days ago to floor to 1');

    // 0.9 days ago
    const almostOneDayAgo = MOCK_NOW - (ONE_DAY_MS * 0.9);
    assertEquals(daysSince(almostOneDayAgo), 0, 'Expected 0.9 days ago to floor to 0');
  });
});

runTest('future dates return negative values', () => {
  withMockedTime(MOCK_NOW, () => {
    // 1 day in the future
    const oneDayFuture = MOCK_NOW + ONE_DAY_MS;
    assertEquals(daysSince(oneDayFuture), -1, 'Expected 1 day in future to return -1');

    // 2.5 days in the future
    const twoAndHalfDaysFuture = MOCK_NOW + (ONE_DAY_MS * 2.5);
    // The current code uses Math.floor, so -2.5 floor becomes -3.
    assertEquals(daysSince(twoAndHalfDaysFuture), -3, 'Expected Math.floor of negative fractional days to result in -3');
  });
});

runTest('numeric timestamp input works', () => {
  withMockedTime(MOCK_NOW, () => {
    const twoDaysAgo = MOCK_NOW - (2 * ONE_DAY_MS);
    assertEquals(daysSince(twoDaysAgo), 2, 'Expected numeric timestamp to work and return 2');
  });
});

updateSummary();
