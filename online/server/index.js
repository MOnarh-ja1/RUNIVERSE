import 'dotenv/config';
import crypto from 'node:crypto';
import express from 'express';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import Database from 'better-sqlite3';
import {OAuth2Client} from 'google-auth-library';
import {validateScore} from './score-rules.js';

const clientId=process.env.GOOGLE_CLIENT_ID;
if(!clientId || clientId==='YOUR_GOOGLE_OAUTH_CLIENT_ID') throw new Error('Set GOOGLE_CLIENT_ID');
const google=new OAuth2Client(clientId);
const db=new Database(process.env.DB_PATH||'./runiverse.sqlite');
db.pragma('journal_mode = WAL');
db.exec(`
CREATE TABLE IF NOT EXISTS players (sub TEXT PRIMARY KEY, display_name TEXT NOT NULL, picture TEXT, created_at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS sessions (token_hash TEXT PRIMARY KEY, player_sub TEXT NOT NULL REFERENCES players(sub), expires_at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS scores (id INTEGER PRIMARY KEY, player_sub TEXT NOT NULL REFERENCES players(sub), distance INTEGER NOT NULL, coins INTEGER NOT NULL, duration_ms INTEGER NOT NULL, created_at INTEGER NOT NULL);
CREATE INDEX IF NOT EXISTS scores_player ON scores(player_sub,distance DESC);
`);
const app=express();
app.disable('x-powered-by');
if(process.env.TRUST_PROXY==='1') app.set('trust proxy',1);
app.use(helmet());
app.use(express.json({limit:'8kb'}));
app.use('/api',rateLimit({windowMs:60000,limit:90,standardHeaders:'draft-7',legacyHeaders:false}));
const now=()=>Math.floor(Date.now()/1000);
const digest=s=>crypto.createHash('sha256').update(s).digest('hex');
const publicProfile=p=>({id:digest(p.sub).slice(0,16),display_name:p.display_name,picture:p.picture});
function auth(req,res,next){
 const match=/^Bearer ([A-Za-z0-9_-]{32,256})$/.exec(req.get('authorization')||'');
 if(!match) return res.status(401).json({error:'login_required'});
 const row=db.prepare('SELECT player_sub,expires_at FROM sessions WHERE token_hash=?').get(digest(match[1]));
 if(!row || row.expires_at<=now()) return res.status(401).json({error:'invalid_session'});
 req.player=db.prepare('SELECT * FROM players WHERE sub=?').get(row.player_sub);
 req.token_hash=digest(match[1]);
 next();
}
app.post('/api/auth/google',async(req,res)=>{
 try {
  const idToken=req.body?.id_token;
  if(typeof idToken!=='string'||idToken.length>8192) return res.status(400).json({error:'invalid_id_token'});
  const ticket=await google.verifyIdToken({idToken,audience:clientId});
  const p=ticket.getPayload();
  if(!p?.sub||!p.email_verified) return res.status(401).json({error:'unverified_google_account'});
  const displayName=String(p.given_name||p.name||'Игрок').trim().slice(0,40)||'Игрок';
  const picture=typeof p.picture==='string'&&p.picture.startsWith('https://')?p.picture.slice(0,500):null;
  db.prepare('INSERT INTO players(sub,display_name,picture,created_at) VALUES(?,?,?,?) ON CONFLICT(sub) DO UPDATE SET display_name=excluded.display_name,picture=excluded.picture').run(p.sub,displayName,picture,now());
  const token=crypto.randomBytes(32).toString('base64url');
  db.prepare('INSERT INTO sessions(token_hash,player_sub,expires_at) VALUES(?,?,?)').run(digest(token),p.sub,now()+30*86400);
  res.json({session_token:token,expires_at:now()+30*86400,player:publicProfile({sub:p.sub,display_name:displayName,picture})});
 } catch(err){console.error('Google sign-in failed:',err.message);res.status(401).json({error:'google_auth_failed'});}
});
app.get('/api/profile',auth,(req,res)=>{
 const stats=db.prepare('SELECT MAX(distance) AS best,COUNT(*) AS runs FROM scores WHERE player_sub=?').get(req.player.sub);
 res.json({player:publicProfile(req.player),best_distance:stats.best||0,runs:stats.runs});
});
app.post('/api/scores',auth,(req,res)=>{
 const error=validateScore(req.body);
 if(error) return res.status(400).json({error});
 const {distance,coins,duration_ms}=req.body;
 db.prepare('INSERT INTO scores(player_sub,distance,coins,duration_ms,created_at) VALUES(?,?,?,?,?)').run(req.player.sub,distance,coins,duration_ms,now());
 res.status(201).json({ok:true,best_distance:db.prepare('SELECT MAX(distance) AS best FROM scores WHERE player_sub=?').get(req.player.sub).best});
});
app.get('/api/leaderboard',(_req,res)=>{
 const rows=db.prepare('SELECT p.sub,p.display_name,p.picture,MAX(s.distance) AS distance FROM scores s JOIN players p ON p.sub=s.player_sub GROUP BY p.sub ORDER BY distance DESC,p.created_at ASC LIMIT 100').all();
 res.json({top:rows.map((p,i)=>({rank:i+1,...publicProfile(p),distance:p.distance}))});
});
app.post('/api/logout',auth,(req,res)=>{db.prepare('DELETE FROM sessions WHERE token_hash=?').run(req.token_hash);res.json({ok:true});});
app.get('/health',(_req,res)=>res.json({ok:true}));
app.listen(Number(process.env.PORT)||3000,()=>console.log('RUNIVERSE online API started'));
