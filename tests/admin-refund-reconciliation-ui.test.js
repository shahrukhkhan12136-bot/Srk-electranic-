'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const html = fs.readFileSync('admin.html', 'utf8');
const scripts = [...html.matchAll(/<script(?:\\s[^>]*)?>([\\s\\S]*?)<\\/script>/gi)]
  .map(match => match[1])
  .filter(source => source.includes('const cfg=window.SRK_CONFIG'));
assert.equal(scripts.length, 1, 'Admin page should contain one application inline script');
assert.doesNotThrow(() => new Function(scripts[0]), 'Admin inline JavaScript must parse');
assert.ok(html.includes("['unknown','processing'].includes(r.status)"),
  'Reconciliation action should only appear for ambiguous/processing refund requests');

const source = scripts[0];
const start = source.indexOf('// --- Admin-only, advisory refund evidence reconciliation.');
const end = source.indexOf('function esc(s){', start);
assert.ok(start >= 0 && end > start, 'Reconciliation workspace block must exist');
const block = source.slice(start, end);
const calls = [];
const nodes = new Map();
const getNode = id => {
  if (!nodes.has(id)) nodes.set(id, {id, value:'', textContent:'', innerHTML:'', checked:false});
  return nodes.get(id);
};
let submitAttempts = 0;
let failFirstSubmit = false;
const evidence = {
  id:'evidence-1', case_id:'case-1', submitted_by:'admin-a',
  provider_refund_id:'rfnd_test123', provider_payment_id:'pay_test123',
  amount_paise:12000, currency:'INR', provider_status:'processed',
  provider_created_at:null, provider_updated_at:null,
  evidence_reference:'Dashboard record checked'
};
const casePayload = {
  case:{id:'case-1', opened_by:'admin-a'},
  refund:{id:'refund-1', payment_id:'pay_test123', amount_paise:12000, currency:'INR',
    status:'unknown', provider_status:'failed', provider_refund_id:null},
  evidence:[evidence], reviews:[], audit:[]
};
let getCasePayload = null;
let actionSequence = 0;
const context = {
  console, Date, JSON, Number, String, Array, Uint8Array, Math,
  window:{crypto:{randomUUID:()=> 'action-'+(++actionSequence)}},
  document:{getElementById:getNode},
  confirm:()=>true,
  alert:()=>{},
  user:{id:'admin-a'},
  sb:{rpc:async(name,args)=>{
    calls.push({name,args});
    if(name==='srk_admin_open_refund_reconciliation_case')return {data:{case_id:'case-1'},error:null};
    if(name==='srk_admin_get_refund_reconciliation_case')return {data:getCasePayload||casePayload,error:null};
    if(name==='srk_admin_submit_refund_reconciliation_evidence'){
      submitAttempts++;
      if(failFirstSubmit&&submitAttempts===1)return {data:null,error:{message:'network timeout'}};
      return {data:{success:true,evidence_id:'evidence-2',replayed:submitAttempts>1},error:null};
    }
    if(name==='srk_admin_review_refund_reconciliation_evidence')
      return {data:{success:true,review_id:'review-1'},error:null};
    throw new Error('Unexpected RPC: '+name);
  }}
};
context.esc = value => String(value??'').replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
vm.createContext(context);
vm.runInContext(block,context);

(async()=>{
  getNode('recon-case-refund-1');
  context.user={id:'admin-a'};
  await context.loadRefundReconciliationCase('case-1','refund-1');
  assert.ok(!getNode('recon-case-refund-1').innerHTML.includes('reviewRefundReconciliationEvidence'),
    'Case opener/evidence submitter must not receive a review action');

  context.user={id:'admin-b'};
  await context.loadRefundReconciliationCase('case-1','refund-1');
  assert.ok(getNode('recon-case-refund-1').innerHTML.includes('reviewRefundReconciliationEvidence'),
    'Independent Admin should receive a review action');
  getNode('recon-decision-evidence-1').value='verified_match';
  getNode('recon-review-note-evidence-1').value='Independent dashboard comparison';
  await context.reviewRefundReconciliationEvidence('evidence-1','case-1','refund-1');
  const review=calls.find(x=>x.name==='srk_admin_review_refund_reconciliation_evidence');
  assert.equal(review.args.p_decision,'verified_match');
  assert.equal(review.args.p_action_id,'action-1');
  assert.equal(review.args.p_review_note,'Independent dashboard comparison');

  const values={
    'recon-provider-refund-case-1':'rfnd_test123',
    'recon-provider-payment-case-1':'pay_test123',
    'recon-provider-amount-case-1':'12000',
    'recon-provider-currency-case-1':'INR',
    'recon-provider-status-case-1':'processed',
    'recon-reference-case-1':'Dashboard record checked'
  };
  for(const [id,value] of Object.entries(values))getNode(id).value=value;
  getNode('recon-evidence-msg-case-1');
  failFirstSubmit=true;submitAttempts=0;
  await context.submitRefundReconciliationEvidence('case-1','refund-1');
  await context.submitRefundReconciliationEvidence('case-1','refund-1');
  const attempts=calls.filter(x=>x.name==='srk_admin_submit_refund_reconciliation_evidence');
  assert.equal(attempts.length,2);
  assert.equal(attempts[0].args.p_action_id,attempts[1].args.p_action_id,
    'Retry after ambiguous network failure must reuse the same Action ID');
  assert.equal(attempts[1].args.p_amount_paise,12000);
  assert.equal(attempts[1].args.p_currency,'INR');

  getCasePayload={...casePayload,evidence:[{...evidence,evidence_reference:'<img src=x onerror=alert(1)>'}]};
  await context.loadRefundReconciliationCase('case-1','refund-1');
  assert.ok(getNode('recon-case-refund-1').innerHTML.includes('&lt;img src=x onerror=alert(1)&gt;'));
  assert.ok(!getNode('recon-case-refund-1').innerHTML.includes('<img src=x onerror=alert(1)>'));

  assert.ok(!block.includes('fetch('));
  assert.ok(!block.includes('sb.from('));
  assert.ok(!block.includes('sb.insert('));
  assert.ok(!block.includes('sb.update('));
  assert.ok(!block.includes('sb.delete('));
  assert.ok(calls.every(x=>x.name.startsWith('srk_admin_')));
  console.log('Admin refund reconciliation UI contract and simulated two-Admin workflow passed.');
})().catch(error=>{console.error(error);process.exitCode=1;});
