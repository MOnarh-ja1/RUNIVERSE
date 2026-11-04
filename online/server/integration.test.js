import test from 'node:test';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {setTimeout as delay} from 'node:timers/promises';

async function request(port,method,path,body,token){
 const response=await fetch(`http://127.0.0.1:${port}${path}`,{
  method,headers:{...(body?{'Content-Type':'application/json'}:{}),...(token?{Authorization:`Bearer ${token}`}:{})},
  body:body?JSON.stringify(body):undefined
 });
 return {status:response.status,data:await response.json()};
}
test('register login profile change credentials and sign in again',async(t)=>{
 const directory=mkdtempSync(join(tmpdir(),'runiverse-online-test-'));
 const port=20500+Math.floor(Math.random()*10000);
 const server=spawn(process.execPath,['index.js'],{
  cwd:import.meta.dirname,
  env:{...process.env,PORT:String(port),GOOGLE_CLIENT_ID:'',TRUST_PROXY:'0',DB_PATH:join(directory,'test.db')},stdio:['ignore','pipe','pipe']
 });
 let errors='';server.stderr.on('data',chunk=>{errors+=chunk.toString()});
 t.after(async()=>{server.kill();rmSync(directory,{recursive:true,force:true})});
 let ready=false;
 for(let i=0;i<60;i++){
  try{const h=await request(port,'GET','/health');if(h.data.ok){ready=true;break;}}
  catch{}
  await delay(150);
 }
 assert.equal(ready,true,'backend did not start: '+errors);
 let r=await request(port,'POST','/api/register',{nickname:'Герой_Тест',password:'Super_Pass_123'});
 assert.equal(r.status,201,JSON.stringify(r));
 assert.equal(r.data.player.display_name,'Герой_Тест');
 const token=r.data.session_token;
 assert.ok(token.length>=32);
 r=await request(port,'POST','/api/register',{nickname:'герой_тест',password:'Different_Pass_123'});
 assert.equal(r.status,409);
 r=await request(port,'POST','/api/login',{nickname:'ГЕРОЙ_ТЕСТ',password:'bad-password'});
 assert.equal(r.status,401);
 r=await request(port,'POST','/api/login',{nickname:'ГЕРОЙ_ТЕСТ',password:'Super_Pass_123'});
 assert.equal(r.status,200);
 assert.equal(r.data.player.display_name,'Герой_Тест');
 r=await request(port,'GET','/api/profile',null,token);
 assert.equal(r.status,200);
 assert.equal(r.data.best_distance,0);
 r=await request(port,'POST','/api/profile/credentials',{nickname:'Новый_Игрок',password:'Other_Safe_Pass_1'},token);
 assert.equal(r.status,200);
 assert.equal(r.data.player.display_name,'Новый_Игрок');
 r=await request(port,'POST','/api/login',{nickname:'Герой_Тест',password:'Super_Pass_123'});
 assert.equal(r.status,401);
 r=await request(port,'POST','/api/login',{nickname:'Новый_Игрок',password:'Other_Safe_Pass_1'});
 assert.equal(r.status,200);
 r=await request(port,'POST','/api/scores',{distance:120,duration_ms:12000,coins:5},r.data.session_token);
 assert.equal(r.status,201);
 r=await request(port,'GET','/api/leaderboard');
 assert.equal(r.status,200);
 assert.equal(r.data.top[0].display_name,'Новый_Игрок');
 r=await request(port,'POST','/api/auth/google',{id_token:'test'});
 assert.equal(r.status,503);
});
