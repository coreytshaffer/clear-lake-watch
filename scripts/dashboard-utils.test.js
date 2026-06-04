import { test, describe, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert';
import { setStoredBoolean } from './dashboard-utils.js';

describe('setStoredBoolean', () => {
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
