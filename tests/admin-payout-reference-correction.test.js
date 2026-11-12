'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const html = fs.readFileSync('admin.html', 'utf8');
const scripts = [...html.matchAll(/<script(?:\\s[^>]*)?>([\\s\\S]*?)<\\/script>/gi)]
  .map(match => match[1])
  .filter(source => source.includes('const cfg=window.SRK_CONFIG'));
assert.equal(scripts.length, 1, 'Admin page must contain exactly one application script');
assert.doesNotThrow(() => new Function(scripts[0]), 'Admin application JavaScript must parse');
assert.ok(html.includes('UTR / भुगतान संदर्भ सुधारें'));
assert.ok(html.includes('srk_admin_correct_electrician_payout_reference'));

const start = scripts[0].indexOf('async function correctPayoutReference(id){');
const end = scripts[0].indexOf('async function markPayoutPaid(id){', start);
assert.ok(start >= 0 && end > start, 'Correction handler must be present before normal payout settlement');
const handler = scripts[0].slice(start, end);

const nodes = new Map();
const getNode = id => {
  if (!nodes.has(id)) nodes.set(id, {value:'', textContent:''});
  return nodes.get(id);
};
let rpcCalls = [];
let reads = 0;
let confirms = [];
let alerts = [];
let refreshed = 0;
let row = {id:'payout-1',electrician_payable:18.5,payout_status:'paid',payout_reference:'9920904161786@ybl'};
const context = {
  document:{getElementById:getNode},
  sb:{
    from:()=>({select:()=>({eq:()=>({single:async()=>{reads++;return {data:row,error:null};}})})}),
    rpc:async(name,args)=>{rpcCalls.push({name,args});return {data:{success:true,reference_corrected:true},error:null};}
  },
  confirm:message=>{confirms.push(message);return true;},
  alert:message=>alerts.push(message),
  loadPayouts:async()=>{refreshed++},
  Number, String, RegExp
};
vm.createContext(context);
vm.runInContext(handler,context);

(async()=>{
  getNode('pc-ref-payout-1').value='741113479944';
  getNode('pc-note-payout-1').value='PhonePe UPI receipt verified by Admin; correcting previously mistyped payout reference.';
  await context.correctPayoutReference('payout-1');
  assert.equal(rpcCalls.length,1);
  assert.equal(rpcCalls[0].name,'srk_admin_correct_electrician_payout_reference');
  assert.equal(rpcCalls[0].args.p_payout_id,'payout-1');
  assert.equal(rpcCalls[0].args.p_expected_reference,'9920904161786@ybl');
  assert.equal(rpcCalls[0].args.p_new_reference,'741113479944');
  assert.ok(confirms[0].includes('₹18.50'));
  assert.equal(refreshed,1);

  rpcCalls=[];alerts=[];refreshed=0;
  getNode('pc-ref-payout-1').value='bad';
  await context.correctPayoutReference('payout-1');
  assert.equal(rpcCalls.length,0,'Invalid UTR must not call the RPC');
  assert.ok(alerts[0].includes('सही UTR'));

  alerts=[];row={...row,payout_status:'pending'};
  getNode('pc-ref-payout-1').value='741113479944';
  await context.correctPayoutReference('payout-1');
  assert.equal(rpcCalls.length,0,'Pending payout must not be corrected');
  assert.ok(alerts[0].includes('Paid'));

  const migration=fs.readFileSync('supabase/migrations/20261112220000_safe_electrician_payout_reference_correction.sql','utf8');
  for(const required of [
    'public.is_srk_admin()','auth.uid() IS NULL',"v_row.payout_status <> 'paid'",
    'p_expected_reference','p_new_reference','payout_reference','payout_note',
    'REVOKE ALL ON FUNCTION','GRANT EXECUTE ON FUNCTION'
  ]) assert.ok(migration.includes(required),'Migration must contain guard: '+required);
  console.log('Admin payout reference correction UI contract passed.');
})().catch(error=>{console.error(error);process.exitCode=1;});
