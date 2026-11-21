'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const migration=fs.readFileSync('supabase/migrations/20261121300000_master_admin_service_catalogue_read_model.sql','utf8');
const admin=fs.readFileSync('admin.html','utf8');
const booking=fs.readFileSync('booking.html','utf8');
test('Admin service taxonomy read model and catalogue mutations are secured',()=>{
 assert.match(migration,/public\.is_srk_admin\(\)/);
 assert.match(migration,/GRANT EXECUTE ON FUNCTION public\.srk_admin_list_master_service_taxonomy\(\) TO authenticated/);
 assert.match(migration,/REVOKE ALL ON FUNCTION public\.srk_admin_list_master_service_taxonomy\(\) FROM PUBLIC,anon/);
 assert.match(admin,/srk_admin_list_master_service_taxonomy/);
 assert.match(admin,/srk_admin_upsert_service_category/);
 assert.match(admin,/srk_admin_upsert_service_skill/);
 assert.match(admin,/srk_admin_upsert_service_offering/);
 assert.match(admin,/srk_admin_upsert_service_rate/);
 assert.match(admin,/srk_admin_list_service_rates/);
});
test('Admin rate form distinguishes hourly Technician/Helper and fixed per-unit prices',()=>{
 assert.match(admin,/masterCatalogueBillingModel/);
 assert.match(admin,/masterCatalogueTechnicianHourly/);
 assert.match(admin,/masterCatalogueHelperHourly/);
 assert.match(admin,/masterCatalogueFixedPrice/);
 assert.match(admin,/pending_admin_configuration/);
 assert.match(admin,/rate_version/);
});
test('Customer booking uses the active Master catalogue, 1–10 Technicians, one Helper per Technician and 50-day timer limit',()=>{
 assert.match(booking,/srk_customer_list_active_service_rates/);
 assert.match(booking,/srk_service_code/);
 assert.match(booking,/srk_rate_level_code/);
 assert.match(booking,/srk_required_technician_count/);
 assert.match(booking,/srk_helper_included/);
 assert.match(booking,/max="1200"/);
 assert.match(booking,/max="10"/);
 assert.doesNotMatch(booking,/const customerRateCard =/);
});
test('Admin and Customer inline scripts parse',()=>{
 for(const [name,source] of [['admin.html',admin],['booking.html',booking]]){
  const scripts=[...source.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)].map(x=>x[1]).filter(x=>x.trim());
  assert.ok(scripts.length>0);
  scripts.forEach((script,index)=>assert.doesNotThrow(()=>new vm.Script(script,{filename:name+'#'+index})));
 }
});

test('Customer cannot select a Helper when the active rate has no approved Helper price',()=>{assert.match(booking,/helperAvailable=!!hourly&&Number\(rate\?\.helper_hourly_paise\|\|0\)>0/);assert.match(booking,/helper\.disabled=!helperAvailable/);});
