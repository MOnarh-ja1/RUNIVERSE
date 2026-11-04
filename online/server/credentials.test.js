import test from 'node:test';
import assert from 'node:assert/strict';
import {normalizeNickname,validatePassword,hashPassword,verifyPassword} from './credentials.js';
test('supports Russian and Latin nicknames',()=>{
 assert.deepEqual(normalizeNickname(' Герой_7 '),{nickname:'Герой_7',nicknameKey:'герой_7'});
 assert.equal(normalizeNickname('<script>'),null);
 assert.equal(normalizeNickname('ab'),null);
});
test('requires sufficiently long passwords',()=>{assert.equal(validatePassword('pass'),false);assert.equal(validatePassword('Safe_pass_123'),true)});
test('password hashes are salted and verifiable',async()=>{
 const first=await hashPassword('Safe_pass_123');const second=await hashPassword('Safe_pass_123');
 assert.notEqual(first,second);
 assert.equal(await verifyPassword('Safe_pass_123',first),true);
 assert.equal(await verifyPassword('wrong_pass',first),false);
});
