import assert from "node:assert/strict";

import { getStoredBoolean, setStoredBoolean } from "./dashboard-utils.js";

const originalLocalStorage = global.localStorage;
const originalConsoleWarn = global.console.warn;

try {
  let storedValue = null;
  global.localStorage = {
    getItem(key) {
      return key === "featureFlag" ? storedValue : null;
    },
    setItem(key, value) {
      if (key !== "featureFlag") {
        throw new Error(`Unexpected key: ${key}`);
      }
      storedValue = value;
    },
  };

  setStoredBoolean("featureFlag", true);
  assert.equal(storedValue, "true");
  assert.equal(getStoredBoolean("featureFlag", false), true);

  const warningError = new Error("Storage full");
  let warned = false;
  global.console.warn = (error) => {
    warned = true;
    assert.equal(error, warningError);
  };

  global.localStorage = {
    getItem() {
      return null;
    },
    setItem() {
      throw warningError;
    },
  };

  setStoredBoolean("featureFlag", true);
  assert.equal(warned, true);
} finally {
  global.localStorage = originalLocalStorage;
  global.console.warn = originalConsoleWarn;
}
