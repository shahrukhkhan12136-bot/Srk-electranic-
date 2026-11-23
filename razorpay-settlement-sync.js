const SUPABASE_URL=process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY=process.env.SUPABASE_SERVICE_ROLE_KEY;
const RAZORPAY_KEY_ID=process.env.RAZORPAY_KEY_ID;
const RAZORPAY_KEY_SECRET=process.env.RAZORPAY_KEY_SECRET;

const json=(statusCode,body)=>({statusCode,headers:{"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store"},body:JSON.stringify(body)});
const isoDate=d=>d.toISOString().slice(0,10);
function monthKeys(from,to){
 const out=[];const d=new Date(Date.UTC(from.getUTCFullYear(),from.getUTCMonth(),1));
 const end=new Date(Date.UTC(to.getUTCFullYear(),to.getUTCMonth(),1));
 while(d<=end){out.push({year:d.getUTCFullYear(),month:d.getUTCMonth()+1});d.setUTCMonth(d.getUTCMonth()+1);}
 return out;
}
async function responseJson(url,options={}){
 const r=await fetch(url,options);const raw=await r.text();let body;
 try{body=raw?JSON.parse(raw):null}catch{body=null}
 if(!r.ok){const e=new Error("External or database request failed");e.status=r.status;e.providerCode=body?.error?.code||null;throw e;}
 return body;
}
async function supabaseRpc(name,args,bearer){
 return responseJson(SUPABASE_URL+"/rest/v1/rpc/"+name,{
  method:"POST",headers:{apikey:SUPABASE_SERVICE_ROLE_KEY,Authorization:"Bearer "+bearer,
   "Content-Type":"application/json",Prefer:"return=representation"},body:JSON.stringify(args)
 });
}
async function razorpay(path){
 return responseJson("https://api.razorpay.com/v1"+path,{
  headers:{Authorization:"Basic "+Buffer.from(RAZORPAY_KEY_ID+":"+RAZORPAY_KEY_SECRET).toString("base64"),
   Accept:"application/json"}
 });
}
exports.handler=async event=>{
 if(event.httpMethod!=="POST")return json(405,{success:false,error:"POST only."});
 if(!SUPABASE_URL||!SUPABASE_SERVICE_ROLE_KEY||!RAZORPAY_KEY_ID||!RAZORPAY_KEY_SECRET)
  return json(500,{success:false,error:"Settlement sync server configuration is incomplete."});
 const auth=event.headers?.authorization||event.headers?.Authorization||"";
 const match=auth.match(/^Bearer\s+(.+)$/i);
 if(!match)return json(401,{success:false,error:"Admin sign-in is required."});
 let body;try{body=JSON.parse(event.body||"{}")}catch{return json(400,{success:false,error:"Invalid JSON body."});}
 const fromSeconds=Number(body.from),toSeconds=Number(body.to);
 if(!Number.isSafeInteger(fromSeconds)||!Number.isSafeInteger(toSeconds)||fromSeconds<=0||toSeconds<=fromSeconds)
  return json(400,{success:false,error:"Valid Unix from/to timestamps are required."});
 const from=new Date(fromSeconds*1000),to=new Date(toSeconds*1000);
 if(!Number.isFinite(from.getTime())||!Number.isFinite(to.getTime())||toSeconds-fromSeconds>90*86400)
  return json(400,{success:false,error:"Settlement sync window must not exceed 90 days."});
 try{
  // The caller's JWT must pass the existing Admin Finance read permission gate.
  await supabaseRpc("srk_admin_finance_dashboard",{p_period:"month",p_anchor_date:isoDate(new Date())},match[1]);

  const settlements=[];
  for(let skip=0;skip<10000;skip+=100){
   const page=await razorpay("/settlements/?"+new URLSearchParams({
    from:String(fromSeconds),to:String(toSeconds),count:"100",skip:String(skip)
   }));
   const items=Array.isArray(page?.items)?page.items:[];
   settlements.push(...items);
   if(items.length<100)break;
   if(skip===9900)throw new Error("Settlement page limit reached; narrow the date range.");
  }
  const reconByMonth=new Map();
  for(const m of monthKeys(from,to)){
   const rows=[];
   for(let skip=0;skip<100000;skip+=1000){
    const q=new URLSearchParams({year:String(m.year),month:String(m.month).padStart(2,"0"),count:"1000",skip:String(skip)});
    const page=await razorpay("/settlements/recon/combined?"+q.toString());
    const items=Array.isArray(page?.items)?page.items:[];
    rows.push(...items);
    if(items.length<1000)break;
    if(skip===99000)throw new Error("Settlement recon page limit reached; narrow the date range.");
   }
   reconByMonth.set(m.year+"-"+m.month,rows);
  }

  const imported=[];
  for(const s of settlements){
   if(!s||typeof s.id!=="string"||!/^setl_[A-Za-z0-9]+$/.test(s.id))continue;
   const d=new Date(Number(s.created_at)*1000);
   const monthRows=reconByMonth.get(d.getUTCFullYear()+"-"+(d.getUTCMonth()+1))||[];
   const items=monthRows.filter(x=>x?.settlement_id===s.id);
   const result=await supabaseRpc("srk_service_import_razorpay_settlement",{
    p_settlement:s,p_recon_items:items,p_source:"api"
   },SUPABASE_SERVICE_ROLE_KEY);
   const r=Array.isArray(result)?result[0]:result;
   imported.push({settlement_id:s.id,status:s.status,recon_items:items.length,
    gross_amount_paise:r?.gross_amount_paise??null,provider_net_amount_paise:r?.provider_net_amount_paise??s.amount});
  }
  return json(200,{success:true,settlements_seen:settlements.length,settlements_imported:imported.length,
   recon_months:reconByMonth.size,results:imported});
 }catch(error){
  const status=error.status===401||error.status===403?403:500;
  console.error("Razorpay settlement sync failed:",error.status||error.name||"Unknown",error.providerCode||"");
  return json(status,{success:false,error:status===403?"Admin permission denied.":"Settlement sync failed; no success is assumed.",provider_code:error.providerCode||undefined});
 }
};
