import 'dotenv/config';
if(process.env.DATABASE_URL){
 await import('./index_pg.js');
}else if(process.env.NODE_ENV==='test'){
 await import('./index_sqlite.js');
}else{
 const {default:express}=await import('express');
 const app=express();
 app.get('/health',(_req,res)=>res.json({ok:false,reason:'database_not_connected'}));
 app.use('/api',(_req,res)=>res.status(503).json({error:'database_not_connected'}));
 app.listen(Number(process.env.PORT)||3000,()=>console.log('RUNIVERSE account service provisioned; waiting for DATABASE_URL'));
}
