import 'dotenv/config';
import crypto from 'node:crypto';
import express from 'express';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import Database from 'better-sqlite3';
import {OAuth2Client} from 'google-auth-library';
import {validateScore} from './score-rules.js';
import {normalizeNickname,validatePassword,hashPassword,verifyPassword} from './credentials.js';

const clientId=process.env.GOOGLE_CLIENT_ID;
const google=clientId?new OAuth2Client(clientId):null;
const db=new Database(process.env.DB_PATH||'./runiverse.sqlite');
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');
db.exec(\`
 CREATE TABLE IF NOT EXISTS accounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nickname TEXT NOT NULL, nickname_key TEXT NOT NULL UNIQUE,
  password_hash TEXT, google_sub TEXT UNIQUE, picture TEXT,
  created_at INTEGER NOT NULL
 );
 CREATE TABLE IF NOT EXISTS account_sessions (
  token_hash TEXT PRIMARY KEY, account_id INTEGER NOT NULL REFERENCES accounts(id),
  expires_at INTEGER NOT NULL
 );
 CREATE TABLE IF NOT EXISTS account_scores (
  id INTEGER PRIMARY KEY, account_id INTEGER NOT NULL REFERENCES accounts(id),
  distance INTEGER NOT NULL, coins INTEGER NOT NULL,
  duration_ms INTEGER NOT NULL, created_at INTEGER NOT NULL
 );
 CREATE INDEX IF NOT EXISTS idx_account_scores_user ON account_scores(account_id, distance DESC);
\`);
const app=express();app.disable('x-powered-by');
if(process.env.TRUST_PROXY==='1')app.set('trust proxy',1);
app.use(helmet());app.use(express.json({limit:'8kb'}));
app.use('/api',rateLimit({windowMs:60*1000,limit:90,standardHeaders:'draft-7',legacyHeaders:false}));
const accountLimit=rateLimit({windowMs:15*60*1000,limit:12,standardHeaders:'draft-7',legacyHeaders:false,message:{error:'too_many_attempts'}});
const now=()=>Math.floor(Date.now()/1000);
const digest=s=>crypto.createHash('sha256').update(s).digest('hex');
const rowById=id=>db.prepare('SELECT * FROM accounts WHERE id=?').get(id);
const publicAccount=a=>({id:String(a.id),display_name:a.nickname,picture:a.picture||''});
function sessionFor(a){
 const token=crypto.randomBytes(32).toString('base64url');
 const exp=now()+30*86400;
 db.prepare('INSERT INTO account_sessions(token_hash,account_id,expires_at) VALUES(?,?,?)').run(digest(token),a.id,exp);
 return {session_token:token,expires_at:exp,player:publicAccount(a)};
}
function optionalAuth(req){
 const match=/^Bearer ([A-Za-z0-9_-]{32,256})$/.exec(req.get('authorization')||'');
 if(!match)return null;
 const token_hash=digest(match[1]);
 const row=db.prepare('SELECT a.* FROM account_sessions s JOIN accounts a ON a.id=s.account_id WHERE s.token_hash=? AND s.expires_at>?').get(token_hash,now());
 return row?{account:row,token_hash}:null;
}
function auth(req,res,next){const found=optionalAuth(req);if(!found)return res.status(401).json({error:'login_required'});Object.assign(req,found);next();}
function apiError(res,error,status=400){return res.status(status).json({error});}
function uniqueNickname(base){
 let nick=base.slice(0,20);let k=nick.toLocaleLowerCase('ru-RU');
 let count=0;
 while(db.prepare('SELECT id FROM accounts WHERE nickname_key=?').get(k)){
  count++;nick=base.slice(0,Math.max(3,20-String(count).length-1))+'_'+count;k=nick.toLocaleLowerCase('ru-RU');
 }
 return {nickname:nick,nicknameKey:k};
}
app.post('/api/register',accountLimit,async(req,res)=>{
 const input=normalizeNickname(req.body?.nickname);
 if(!input)return apiError(res,'invalid_nickname');
 if(!validatePassword(req.body?.password))return apiError(res,'weak_password');
 if(db.prepare('SELECT id FROM accounts WHERE nickname_key=?').get(input.nicknameKey))return apiError(res,'nickname_taken',409);
 try{
  const passhash=await hashPassword(req.body.password);
  const result=db.prepare('INSERT INTO accounts(nickname,nickname_key,password_hash,created_at) VALUES(?,?,?,?)').run(input.nickname,input.nicknameKey,passhash,now());
  return res.status(201).json(sessionFor(rowById(result.lastInsertRowid)));
 }catch(err){if(err.code?.startsWith('SQLITE_CONSTRAINT'))return apiError(res,'nickname_taken',409);console.error('Registration error:',err.code||err.message);return apiError(res,'server_error',500);}
});
app.post('/api/login',accountLimit,async(req,res)=>{
 const input=normalizeNickname(req.body?.nickname);
 if(!input||typeof req.body?.password!=='string')return apiError(res,'invalid_credentials',401);
 const account=db.prepare('SELECT * FROM accounts WHERE nickname_key=?').get(input.nicknameKey);
 const fallback='scrypt-v1:000000000000000000000000000000000000000000000000:23ca2ed9d23cb26130da55052b5a0c2057db5c05249cf8d46a4273b1af74239b3b81ac79bff78bf99ac740ef6450a6ca66cd657cb0dc7fafb3408452a39c9920';
 const ok=await verifyPassword(req.body.password,account?.password_hash||fallback);
 if(!account||!ok)return apiError(res,'invalid_credentials',401);
 return res.json(sessionFor(account));
});
app.post('/api/auth/google',accountLimit,async(req,res)=>{
 if(!google)return apiError(res,'google_not_configured',503);
 try{
  const idToken=req.body?.id_token;
  if(typeof idToken!=='string'||idToken.length>8192)return apiError(res,'invalid_id_token');
  const ticket=await google.verifyIdToken({idToken,audience:clientId});
  const p=ticket.getPayload();
  if(!p?.sub||!p.email_verified)return apiError(res,'unverified_google_account',401);
  const linked=db.prepare('SELECT * FROM accounts WHERE google_sub=?').get(p.sub);
  const active=optionalAuth(req);
  if(active&&linked&&linked.id!==active.account.id)return apiError(res,'google_already_linked',409);
  let account;
  if(active){
   db.prepare('UPDATE accounts SET google_sub=?,picture=? WHERE id=?').run(p.sub,typeof p.picture==='string'&&p.picture.startsWith('https://')?p.picture.slice(0,500):null,active.account.id);
   account=rowById(active.account.id);
  }else if(linked){account=linked;}
  else{
   const n=uniqueNickname(('Игрок_'+digest(p.sub).slice(0,9)));
   const result=db.prepare('INSERT INTO accounts(nickname,nickname_key,google_sub,picture,created_at) VALUES(?,?,?,?,?)').run(n.nickname,n.nicknameKey,p.sub,typeof p.picture==='string'&&p.picture.startsWith('https://')?p.picture.slice(0,500):null,now());
   account=rowById(result.lastInsertRowid);
  }
  return res.json(sessionFor(account));
 }catch(err){console.error('Google auth error',err.message);return apiError(res,'google_auth_failed',401);}
});
app.get('/api/profile',auth,(req,res)=>{
 const stats=db.prepare('SELECT MAX(distance) AS best,COUNT(*) AS runs FROM account_scores WHERE account_id=?').get(req.account.id);
 return res.json({player:publicAccount(req.account),best_distance:stats.best||0,runs:stats.runs,google_linked:!!req.account.google_sub,has_password:!!req.account.password_hash});
});
app.post('/api/profile/credentials',auth,accountLimit,async(req,res)=>{
 const hasNickname=typeof req.body?.nickname==='string'&&req.body.nickname.trim().length>0;
 const hasPassword=typeof req.body?.password==='string'&&req.body.password.length>0;
 if(!hasNickname&&!hasPassword)return apiError(res,'nothing_to_change');
 let input=hasNickname?normalizeNickname(req.body.nickname):null;
 if(hasNickname&&!input)return apiError(res,'invalid_nickname');
 if(hasPassword&&!validatePassword(req.body.password))return apiError(res,'weak_password');
 if(input){const existing=db.prepare('SELECT id FROM accounts WHERE nickname_key=?').get(input.nicknameKey);if(existing&&existing.id!==req.account.id)return apiError(res,'nickname_taken',409);}
 try{
  const hash=hasPassword?await hashPassword(req.body.password):req.account.password_hash;
  db.prepare('UPDATE accounts SET nickname=?,nickname_key=?,password_hash=? WHERE id=?').run(input?.nickname||req.account.nickname,input?.nicknameKey||req.account.nickname_key,hash,req.account.id);
  return res.json({ok:true,player:publicAccount(rowById(req.account.id))});
 }catch(err){if(err.code?.startsWith('SQLITE_CONSTRAINT'))return apiError(res,'nickname_taken',409);return apiError(res,'server_error',500);}
});
app.post('/api/scores',auth,(req,res)=>{
 const error=validateScore(req.body);if(error)return apiError(res,error);
 const {distance,coins,duration_ms}=req.body;
 db.prepare('INSERT INTO account_scores(account_id,distance,coins,duration_ms,created_at) VALUES(?,?,?,?,?)').run(req.account.id,distance,coins,duration_ms,now());
 return res.status(201).json({ok:true,best_distance:db.prepare('SELECT MAX(distance) AS best FROM account_scores WHERE account_id=?').get(req.account.id).best});
});
app.get('/api/leaderboard',(_req,res)=>{
 const rows=db.prepare('SELECT a.id,a.nickname,a.picture,MAX(s.distance) AS distance FROM account_scores s JOIN accounts a ON a.id=s.account_id GROUP BY a.id ORDER BY distance DESC,a.created_at ASC LIMIT 100').all();
 return res.json({top:rows.map((p,i)=>({rank:i+1,id:String(p.id),display_name:p.nickname,picture:p.picture,distance:p.distance}))});
});
app.post('/api/logout',auth,(req,res)=>{db.prepare('DELETE FROM account_sessions WHERE token_hash=?').run(req.token_hash);res.json({ok:true});});
app.get('/health',(_req,res)=>res.json({ok:true}));
app.listen(Number(process.env.PORT)||3000,()=>console.log('RUNIVERSE accounts API online'));
