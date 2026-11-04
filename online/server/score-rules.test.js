import test from 'node:test';
import assert from 'node:assert/strict';
import {validateScore} from './score-rules.js';
test('plausible run',()=>assert.equal(validateScore({distance:300,duration_ms:30000,coins:25}),null));
test('reject forged high distance',()=>assert.ok(validateScore({distance:9000,duration_ms:10000,coins:25})));
test('reject string values',()=>assert.ok(validateScore({distance:'500',duration_ms:10000,coins:25})));
