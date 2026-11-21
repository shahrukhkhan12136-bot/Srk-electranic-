'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const migration=fs.readFileSync('supabase/migrations/20261121280000_master_skill_level_admin_queue.sql','utf8');
const admin=fs.readFileSync('admin.html','utf8');
const technician=fs.readFileSync('electrician.html','utf8');
test('Admin skill-level queue is Main Admin-only and only exposes approved skills with active rates',()=>{
 assert.match(migration,/public\.is_srk_admin\(\)/);
 assert.match(migration,/a\.status='approved'/);
 assert.match(migration,/aps\.review_status='approved'/);
 assert.match(migration,/r\.status='active'/);
 assert.match(migration,/GRANT EXECUTE ON FUNCTION public\.srk_admin_list_master_skill_level_options\(\) TO authenticated/);
 assert.match(migration,/REVOKE ALL ON FUNCTION public\.srk_admin_list_master_skill_level_options\(\) FROM PUBLIC,anon/);
});
test('Admin can assign an available approved skill level through the audited RPC',()=>{
 assert.match(admin,/srk_admin_list_master_skill_level_options/);
 assert.match(admin,/srk_admin_set_technician_skill_level/);
 assert.match(admin,/masterSkillLevelSelect_/);
});
test('Technician app displays only own Admin-approved 85 percent rate list',()=>{
 assert.match(technician,/srk_technician_list_my_85_percent_rates/);
 assert.match(technician,/partnerMasterRateList/);
 assert.match(technician,/technician_share_85_paise/);
 assert.match(technician,/fixed_share_85_paise/);
 assert.doesNotMatch(technician,/platform_commission_paise/);
});
test('Admin and Technician inline JavaScript parse',()=>{
 for(const [name,source] of [['admin.html',admin],['electrician.html',technician]]){
  const scripts=[...source.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)].map(x=>x[1]).filter(x=>x.trim());
  assert.ok(scripts.length>0);
  scripts.forEach((script,index)=>assert.doesNotThrow(()=>new vm.Script(script,{filename:name+'#'+index})));
 }
});
