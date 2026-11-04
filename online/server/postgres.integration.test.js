import test from 'node:test';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {setTimeout as delay} from 'node:timers/promises';

async function req(port,method,path,body,token) {
 const resp=await fetch('http://127.0.0.1:'+port+path,{method,
  headers:{...(body?{'Content-Type':'application/json'}:{}),...(token?{Authorization:'Bearer '+token}:{})},
  body:body?JSON.stringify(body):undefined});
 return {status:resp.status,data:await resp.json()};
}
test('Postgres server registers persists and authenticates accounts',async t=>{
 if(!process.env.DATABASE_URL) return t.skip('DATABASE_URL required');
 const port=22000+Math.floor(Math.random()*10000);
 const proc=spawn(process.execPath,['index_pg.js'],{cwd:import.meta.dirname,env:{...process.env,PORT:String(port),GOOGLE_CLIENT_ID:''},stdio:['ignore','pipe','pipe']});
 let errors='';proc.stderr.on('data',b=>{errors+=b.toString()});
 t.after(()=>proc.kill());
 let ok=false;
 for(let n=0;n<75;n++){
  try{let h=await req(port,'GET','/health');if(h.data.ok){ok=true;break}}catch{}
  await delay(150);
 }
 assert.equal(ok,true,'PG API did not start: '+errors);
 const nickname='Test_'+Date.now().toString(36).slice(-8);
 let r=await req(port,'POST','/api/register',{nickname,password:'Safe_Pass_12345'});
 assert.equal(r.status,201,JSON.stringify(r));
 const token=r.data.session_token;
 r=await req(port,'POST','/api/login',{nickname,password:'Safe_Pass_12345'});
 assert.equal(r.status,200,JSON.stringify(r));
 r=await req(port,'GET','/api/profile',null,token);
 assert.equal(r.status,200);
 assert.equal(r.data.player.display_name,nickname);
 r=await req(port,'POST','/api/profile/credentials',{nickname:'Renamed_'+Date.now().toString(36).slice(-8),password:'New_Pass_98765'},token);
 assert.equal(r.status,200,JSON.stringify(r));
 const newNick=r.data.player.display_name;
 r=await req(port,'POST','/api/login',{nickname:newNick,password:'New_Pass_98765'});
 assert.equal(r.status,200,JSON.stringify(r));
 r=await req(port,'POST','/api/scores',{distance:120,duration_ms:12000,coins:5},r.data.session_token);
 assert.equal(r.status,201,JSON.stringify(r));
 r=await req(port,'GET','/api/leaderboard');
 assert.equal(r.status,200);
 assert.equal(r.data.top[0].display_name,newNick);
});
