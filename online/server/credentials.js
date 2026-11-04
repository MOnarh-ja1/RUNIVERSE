import crypto from 'node:crypto';
import {promisify} from 'node:util';
const scrypt=promisify(crypto.scrypt);
export function normalizeNickname(value) {
  if (typeof value !== 'string') return null;
  const nickname=value.normalize('NFC').trim();
  if (!/^[\p{L}\p{N}_]{3,20}$/u.test(nickname)) return null;
  return {nickname,nicknameKey:nickname.toLocaleLowerCase('ru-RU')};
}
export function validatePassword(value) {
  return typeof value==='string' && value.length>=8 && value.length<=128 && Buffer.byteLength(value,'utf8')<=256;
}
export async function hashPassword(password) {
  if (!validatePassword(password)) throw new Error('invalid_password');
  const salt=crypto.randomBytes(24).toString('hex');
  const derived=await scrypt(password,salt,64,{N:16384,r:8,p:1,maxmem:32*1024*1024});
  return `scrypt-v1:${salt}:${derived.toString('hex')}`;
}
export async function verifyPassword(password,encoded) {
  if (!validatePassword(password)||typeof encoded!=='string')return false;
  const parts=encoded.split(':');
  if (parts.length!==3||parts[0]!=='scrypt-v1'||!/^[a-f0-9]{48}$/.test(parts[1])||!/^[a-f0-9]{128}$/.test(parts[2]))return false;
  const target=Buffer.from(parts[2],'hex');
  const derived=await scrypt(password,parts[1],64,{N:16384,r:8,p:1,maxmem:32*1024*1024});
  return crypto.timingSafeEqual(target,derived);
}
