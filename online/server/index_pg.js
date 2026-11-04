import 'dotenv/config';
import crypto from 'node:crypto';
import express from 'express';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import pg from 'pg';
import {OAuth2Client} from 'google-auth-library';
import {validateScore} from './score-rules.js';
import {normalizeNickname,validatePassword,hashPassword,verifyPassword} from './credentials.js';

const app=express();
app.disable('x-powered-by');
if(process.env.TRUST_PROXY==='1') app.set('trust proxy',1);
app.use(helmet());
app.use(express.json({limit:'8kb'}));
app.use('/api',rateLimit({windowMs:60000,limit:90,standardHeaders:'draft-7',legacyHeaders:false}));
const authLimit=rateLimit({windowMs:900000,limit:12,standardHeaders:'draft-7',legacyHeaders:false,message:{error:'too_many_attempts'}});
const pool=process.env.DATABASE_URL?new pg.Pool({connectionString:process.env.DATABASE_URL,max:5,connectionTimeoutMillis:10000}):null;
const googleClientId=process.env.GOOGLE_CLIENT_ID||'';
const google=googleClientId?new OAuth2Client(googleClientId):null;
const now=()=>Math.floor(Date.now()/1000);
const digest=s=>crypto.createHash('sha256').update(s).digest('hex');
const pub=a=>({id:String(a.id),display_name:a.nickname,picture:a.picture||''});
const fail=(res,error,status=400)=>res.status(status).json({error});
const sql=(statement,params=[])=>pool.query(statement,params);
let ready=false;
async function prepare(){
 if(!pool)throw new Error('DATABASE_URL is not set');
 for(const statement of [
  'CREATE TABLE IF NOT EXISTS accounts (id BIGSERIAL PRIMARY KEY,nickname TEXT NOT NULL,nickname_key TEXT NOT NULL UNIQUE,password_hash TEXT,google_sub TEXT UNIQUE,picture TEXT,created_at BIGINT NOT NULL)',
  'CREATE TABLE IF NOT EXISTS account_sessions (token_hash TEXT PRIMARY KEY,account_id BIGINT NOT NULL REFERENCES accounts(id),expires_at BIGINT NOT NULL)',
  'CREATE TABLE IF NOT EXISTS account_scores (id BIGSERIAL PRIMARY KEY,account_id BIGINT NOT NULL REFERENCES accounts(id),distance INTEGER NOT NULL,coins INTEGER NOT NULL,duration_ms INTEGER NOT NULL,created_at BIGINT NOT NULL)',
  'CREATE INDEX IF NOT EXISTS idx_account_scores_user ON account_scores(account_id,distance DESC)'
 ])await sql(statement);
 ready=true;
}
async function session(a){
 const token=crypto.randomBytes(32).toString('base64url');
 const expiry=now()+30*86400;
 await sql('INSERT INTO account_sessions(token_hash,account_id,expires_at) VALUES($1,$2,$3)',[digest(token),a.id,expiry]);
 return {session_token:token,expires_at:expiry,player:pub(a)};
}
async function optionalAuth(req){
 const m=/^Bearer ([A-Za-z0-9_-]{32,256})$/.exec(req.get('authorization')||'');
 if(!m)return null;
 const hash=digest(m[1]);
 const rows=await sql('SELECT a.* FROM account_sessions s JOIN accounts a ON a.id=s.account_id WHERE s.token_hash=$1 AND s.expires_at>$2',[hash,now()]);
 return rows.rows.length?{account:rows.rows[0],token_hash:hash}:null;
}
async function auth(req,res,next){try{
 const user=await optionalAuth(req);
 if(!user)return fail(res,'login_required',401);
 Object.assign(req,user);
 next();
}catch(e){next(e)}}
app.use('/api',(req,res,next)=>ready?next():fail(res,'database_not_ready',503));
app.post('/api/register',authLimit,async(req,res,next)=>{try{
 const n=normalizeNickname(req.body?.nickname);
 if(!n)return fail(res,'invalid_nickname');
 if(!validatePassword(req.body?.password))return fail(res,'weak_password');
 const hash=await hashPassword(req.body.password);
 const result=await sql('INSERT INTO accounts(nickname,nickname_key,password_hash,created_at) VALUES($1,$2,$3,$4) ON CONFLICT(nickname_key) DO NOTHING RETURNING *',[n.nickname,n.nicknameKey,hash,now()]);
 if(!result.rows.length)return fail(res,'nickname_taken',409);
 res.status(201).json(await session(result.rows[0]));
}catch(e){next(e)}});
app.post('/api/login',authLimit,async(req,res,next)=>{try{
 const n=normalizeNickname(req.body?.nickname);
 if(!n||!validatePassword(req.body?.password))return fail(res,'invalid_credentials',401);
 const result=await sql('SELECT * FROM accounts WHERE nickname_key=$1',[n.nicknameKey]);
 const a=result.rows[0];
 // An invalid account still performs a password hash check to reduce timing-based enumeration.
 const dummy='scrypt-v1:000000000000000000000000000000000000000000000000:23ca2ed9d23cb26130da55052b5a0c2057db5c05249cf8d46a4273b1af74239b3b81ac79bff78bf99ac740ef6450a6ca66cd657cb0dc7fafb3408452a39c9920';
 const valid=await verifyPassword(req.body.password,a?.password_hash||dummy);
 if(!a||!valid)return fail(res,'invalid_credentials',401);
 res.json(await session(a));
}catch(e){next(e)}});
async function applyGoogleToken(req,res,idToken){
 if(typeof idToken!=='string'||idToken.length>8192)return fail(res,'invalid_id_token');
 const ticket=await google.verifyIdToken({idToken,audience:googleClientId});
 const p=ticket.getPayload();
 if(!p?.sub||!p.email_verified)return fail(res,'unverified_google_account',401);
 const active=await optionalAuth(req);
 const linked=(await sql('SELECT * FROM accounts WHERE google_sub=$1',[p.sub])).rows[0];
 if(active&&linked&&String(linked.id)!==String(active.account.id))return fail(res,'google_already_linked',409);
 const picture=typeof p.picture==='string'&&p.picture.startsWith('https://')?p.picture.slice(0,500):null;
 let a;
 if(active){
  a=(await sql('UPDATE accounts SET google_sub=$1,picture=$2 WHERE id=$3 RETURNING *',[p.sub,picture,active.account.id])).rows[0];
 }else if(linked){a=linked;}
 else{
  const nick='Игрок_'+digest(p.sub).slice(0,12);
  a=(await sql('INSERT INTO accounts(nickname,nickname_key,google_sub,picture,created_at) VALUES($1,$2,$3,$4,$5) ON CONFLICT(google_sub) DO UPDATE SET picture=EXCLUDED.picture RETURNING *',[nick,nick.toLowerCase(),p.sub,picture,now()])).rows[0];
 }
 return res.json(await session(a));
}
function googleError(err,res,next){
 if(err.code==='23505')return fail(res,'nickname_taken',409);
 if(err.message?.includes('jwt')||err.message?.includes('Token used')||err.message?.includes('Wrong recipient')||err.message?.includes('Invalid token'))return fail(res,'google_auth_failed',401);
 next(err);
}
app.post('/api/auth/google',authLimit,async(req,res,next)=>{try{
 if(!google)return fail(res,'google_not_configured',503);
 return await applyGoogleToken(req,res,req.body?.id_token);
}catch(e){googleError(e,res,next)}});
// Native desktop OAuth: browser -> loopback listener -> HTTPS API -> Google token endpoint.
// The app sends only the one-use authorization code and PKCE verifier; never a Google password.
// GOOGLE_CLIENT_SECRET (when required for Desktop clients) is kept ONLY in Render environment.
app.post('/api/auth/google/code',authLimit,async(req,res,next)=>{try{
 if(!google)return fail(res,'google_not_configured',503);
 const code=req.body?.code, verifier=req.body?.code_verifier, redirect=req.body?.redirect_uri;
 if(typeof code!=='string'||code.length<10||code.length>4096 ||
    typeof verifier!=='string'||!(/^[A-Za-z0-9_.~-]{43,128}$/).test(verifier) ||
    typeof redirect!=='string'||!(/^http:\/\/127\.0\.0\.1:[0-9]{1,5}\/callback$/).test(redirect) ||
    Number(new URL(redirect).port)<1)return fail(res,'invalid_google_oauth_request');
 const form=new URLSearchParams({
  code,code_verifier:verifier,redirect_uri:redirect,
  grant_type:'authorization_code',client_id:googleClientId
 });
 if(process.env.GOOGLE_CLIENT_SECRET)form.set('client_secret',process.env.GOOGLE_CLIENT_SECRET);
 const response=await fetch('https://oauth2.googleapis.com/token',{
  method:'POST',
  headers:{'Content-Type':'application/x-www-form-urlencoded'},
  body:form,
  signal:AbortSignal.timeout(25000)
 });
 const data=await response.json();
 if(!response.ok || typeof data?.id_token!=='string'){
  const googleCode=typeof data?.error==='string' ? data.error : 'unknown';
  console.warn('Google token exchange failed:',googleCode);
  if(googleCode==='invalid_request'&&!process.env.GOOGLE_CLIENT_SECRET)
   return fail(res,'google_client_secret_required',503);
  return fail(res,'google_code_exchange_failed_'+googleCode,401);
 }
 return await applyGoogleToken(req,res,data.id_token);
}catch(e){googleError(e,res,next)}});
app.get('/api/profile',auth,async(req,res,next)=>{try{
 const r=(await sql('SELECT COALESCE(MAX(distance),0)::integer AS best,COUNT(*)::integer AS runs FROM account_scores WHERE account_id=$1',[req.account.id])).rows[0];
 res.json({player:pub(req.account),best_distance:r.best,runs:r.runs,google_linked:!!req.account.google_sub,has_password:!!req.account.password_hash});
}catch(e){next(e)}});
app.post('/api/profile/credentials',auth,authLimit,async(req,res,next)=>{try{
 const changeNick=typeof req.body?.nickname==='string'&&req.body.nickname.trim().length>0;
 const changePassword=typeof req.body?.password==='string'&&req.body.password.length>0;
 if(!changeNick&&!changePassword)return fail(res,'nothing_to_change');
 const n=changeNick?normalizeNickname(req.body.nickname):null;
 if(changeNick&&!n)return fail(res,'invalid_nickname');
 if(changePassword&&!validatePassword(req.body.password))return fail(res,'weak_password');
 const hash=changePassword?await hashPassword(req.body.password):req.account.password_hash;
 const result=await sql('UPDATE accounts SET nickname=$1,nickname_key=$2,password_hash=$3 WHERE id=$4 RETURNING *',[n?.nickname||req.account.nickname,n?.nicknameKey||req.account.nickname_key,hash,req.account.id]);
 res.json({ok:true,player:pub(result.rows[0])});
}catch(e){if(e.code==='23505')return fail(res,'nickname_taken',409);next(e)}});
app.post('/api/scores',auth,async(req,res,next)=>{try{
 const error=validateScore(req.body);if(error)return fail(res,error);
 const {distance,coins,duration_ms}=req.body;
 await sql('INSERT INTO account_scores(account_id,distance,coins,duration_ms,created_at) VALUES($1,$2,$3,$4,$5)',[req.account.id,distance,coins,duration_ms,now()]);
 const best=(await sql('SELECT MAX(distance) AS best FROM account_scores WHERE account_id=$1',[req.account.id])).rows[0].best;
 res.status(201).json({ok:true,best_distance:best});
}catch(e){next(e)}});
app.get('/api/leaderboard',async(_req,res,next)=>{try{
 const r=await sql('SELECT a.id,a.nickname,a.picture,MAX(s.distance) AS distance FROM account_scores s JOIN accounts a ON a.id=s.account_id GROUP BY a.id ORDER BY distance DESC,MIN(s.created_at) ASC LIMIT 100');
 res.json({top:r.rows.map((x,i)=>({rank:i+1,id:String(x.id),display_name:x.nickname,picture:x.picture,distance:x.distance}))});
}catch(e){next(e)}});
app.post('/api/logout',auth,async(req,res,next)=>{try{await sql('DELETE FROM account_sessions WHERE token_hash=$1',[req.token_hash]);res.json({ok:true})}catch(e){next(e)}});
app.get('/health',(_req,res)=>res.status(ready?200:503).json({ok:ready,db:ready?'connected':'not_ready'}));
app.use((err,_req,res,_next)=>{console.error('API error',err.code||err.message);if(!res.headersSent)fail(res,'server_error',500)});
const port=Number(process.env.PORT)||3000;
app.listen(port,()=>console.log('RUNIVERSE PostgreSQL API listening'));
prepare().catch(e=>console.error('Postgres unavailable:',e.code||e.message));
