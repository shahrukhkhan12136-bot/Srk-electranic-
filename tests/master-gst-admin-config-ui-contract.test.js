'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const admin=fs.readFileSync('admin.html','utf8');
test('Main Admin GST company profile form exposes registration and invoice settings',()=>{
 for(const id of ['masterGstRegistrationStatus','masterGstLegalName','masterGstGstin','masterGstSupplierState','masterGstInvoicePrefix','masterGstCompanyEffective'])assert.match(admin,new RegExp('id="'+id+'"'));
 assert.match(admin,/srk_admin_configure_gst_company/);
 assert.match(admin,/p_registration_status:registration/);
 assert.match(admin,/Unregistered स्थिति में GSTIN और State Code खाली रखें/);
});
test('GST service rules require explicit component, taxability, rate and effective date',()=>{
 for(const id of ['masterGstRuleCategory','masterGstRuleService','masterGstRuleComponent','masterGstRuleTaxable','masterGstRuleRate','masterGstRuleEffective'])assert.match(admin,new RegExp('id="'+id+'"'));
 assert.match(admin,/srk_admin_upsert_gst_service_rule/);
 assert.match(admin,/p_gst_rate_basis_points:Math\.round\(rate\*100\)/);
 assert.match(admin,/पहले GST Company Profile को Registered के रूप में सुरक्षित करें/);
});
test('GST configuration actions are Main Admin-only and preserve historical snapshots',()=>{
 assert.match(admin,/adminPortalMode!=='main_admin'/);
 assert.match(admin,/पुराने Booking Tax Snapshots नहीं बदलेंगे/);
 assert.match(admin,/GST शून्य/);
});
test('Admin inline JavaScript parses after GST form integration',()=>{
 const scripts=[...admin.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)].map(x=>x[1]).filter(x=>x.trim());
 assert.ok(scripts.length>0);
 scripts.forEach((source,index)=>assert.doesNotThrow(()=>new vm.Script(source,{filename:'admin.html#'+index})));
});
