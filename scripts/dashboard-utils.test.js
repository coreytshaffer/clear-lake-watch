import { test, describe, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert';
import { getStoredBoolean, setStoredBoolean, getStoredJson, setStoredJson } from './dashboard-utils.js';

let originalLocalStorage;
let originalConsoleWarn;

beforeEach(() => {
    originalLocalStorage = global.localStorage;
    originalConsoleWarn = global.console.warn;
});

afterEach(() => {
    global.localStorage = originalLocalStorage;
    global.console.warn = originalConsoleWarn;
});

describe('setStoredBoolean', () => {

    test('should call localStorage.setItem successfully', () => {
        let setItemCalled = false;
        let setItemArgs = null;

        global.localStorage = {
            setItem: (...args) => {
                setItemCalled = true;
                setItemArgs = args;
            }
        };

        setStoredBoolean('testKey', true);

        assert.strictEqual(setItemCalled, true, 'localStorage.setItem should be called');
        assert.deepStrictEqual(setItemArgs, ['testKey', 'true'], 'localStorage.setItem should be called with stringified value');
    });

    test('should catch error and call console.warn when localStorage.setItem throws', () => {
        const fakeError = new Error('Storage full');

        global.localStorage = {
            setItem: () => {
                throw fakeError;
            }
        };

        let warnCalled = false;
        let warnArgs = null;
        global.console.warn = (...args) => {
            warnCalled = true;
            warnArgs = args;
        };

        setStoredBoolean('testKey', true);

        assert.strictEqual(warnCalled, true, 'console.warn should be called');
        assert.strictEqual(warnArgs[0], fakeError, 'console.warn should be called with the thrown error');
    });
});

describe('getStoredBoolean', () => {
    test('returns the supplied fallback when the key is missing', () => {
        global.localStorage = { getItem: () => null };

        assert.strictEqual(getStoredBoolean('featureFlag', true), true);
    });

    test('returns stored false even when the fallback is true', () => {
        global.localStorage = { getItem: () => 'false' };

        assert.strictEqual(getStoredBoolean('featureFlag', true), false);
    });

    test('returns the fallback and warns when storage throws', (t) => {
        const error = new Error('Storage access denied');
        const warn = t.mock.method(console, 'warn', () => {});
        global.localStorage = {
            getItem() {
                throw error;
            },
        };

        assert.strictEqual(getStoredBoolean('featureFlag', true), true);
        assert.deepStrictEqual(warn.mock.calls.map(call => call.arguments), [[error]]);
    });
});

describe('getStoredJson', () => {
    test('returns the parsed stored value', () => {
        global.localStorage = { getItem: () => '{"enabled":true,"labels":["sample"]}' };

        assert.deepStrictEqual(getStoredJson('settings'), { enabled: true, labels: ['sample'] });
    });

    test('returns the supplied fallback when the key is missing', () => {
        const fallback = { enabled: false };
        global.localStorage = { getItem: () => null };

        assert.strictEqual(getStoredJson('settings', fallback), fallback);
    });

    test('returns the fallback and warns when stored JSON is malformed', (t) => {
        const fallback = { enabled: false };
        const warn = t.mock.method(console, 'warn', () => {});
        global.localStorage = { getItem: () => '{"enabled":' };

        assert.strictEqual(getStoredJson('settings', fallback), fallback);
        assert.strictEqual(warn.mock.callCount(), 1);
        assert.ok(warn.mock.calls[0].arguments[0] instanceof SyntaxError);
    });

    test('returns the fallback and warns when storage throws', (t) => {
        const fallback = { enabled: false };
        const error = new Error('Storage access denied');
        const warn = t.mock.method(console, 'warn', () => {});
        global.localStorage = {
            getItem() {
                throw error;
            },
        };

        assert.strictEqual(getStoredJson('settings', fallback), fallback);
        assert.deepStrictEqual(warn.mock.calls.map(call => call.arguments), [[error]]);
    });
});

describe('setStoredJson', () => {
    test('writes the serialized value to the requested key', (t) => {
        const setItem = t.mock.fn();
        global.localStorage = { setItem };

        setStoredJson('settings', { enabled: true, labels: ['sample'] });

        assert.deepStrictEqual(setItem.mock.calls.map(call => call.arguments), [
            ['settings', '{"enabled":true,"labels":["sample"]}'],
        ]);
    });

    test('warns when the storage write fails', (t) => {
        const error = new Error('Storage full');
        const warn = t.mock.method(console, 'warn', () => {});
        global.localStorage = {
            setItem() {
                throw error;
            },
        };

        setStoredJson('settings', { enabled: true });

        assert.deepStrictEqual(warn.mock.calls.map(call => call.arguments), [[error]]);
    });

    test('warns and skips the write when serialization fails', (t) => {
        const setItem = t.mock.fn();
        const warn = t.mock.method(console, 'warn', () => {});
        const settings = {};
        settings.self = settings;
        global.localStorage = { setItem };

        setStoredJson('settings', settings);

        assert.strictEqual(setItem.mock.callCount(), 0);
        assert.strictEqual(warn.mock.callCount(), 1);
        assert.ok(warn.mock.calls[0].arguments[0] instanceof TypeError);
    });
});
