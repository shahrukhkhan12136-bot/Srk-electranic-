'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const migration=fs.readFileSync(path.join(root,'supabase/migrations/20261122000300_master_confirmed_service_rates.sql'),'utf8');
const booking=fs.readFileSync(path.join(root,'booking.html'),'utf8');
test('Only confirmed SRK service rates are activated with exact Technician and Helper splits',()=>{
 for(const value of [
  "'residential_wiring','basic','Basic',10000,0",
  "'residential_wiring','expert','Expert Residential',12500,6250",
  "'factory_wiring','expert','Expert Factory / Industrial Wiring',30000,12500",
  "'residential_wiring','master','Master Electrician',70000,20000",
  "'fridge_technician','standard','Fridge Technician + Helper',15000,7500",
  "'cooler_repair','standard','Cooler Repair / per cooler',NULL,0,50000"
 ])assert.ok(migration.includes(value),'missing approved rate: '+value);
 assert.match(booking,/Technician 8h/);
 assert.match(booking,/Helper 8h/);
 assert.match(booking,/Combined 8h/);
});
test('Motor and Cooler winding include all ten approved HP fixed rates',()=>{
 assert.equal((migration.match(/'motor_winding','hp_/g)||[]).length,10);
 assert.equal((migration.match(/'cooler_motor_winding','hp_/g)||[]).length,10);
 for(const amount of [50000,60000,70000,80000,90000,100000,110000,120000,130000,140000])assert.ok(migration.includes(String(amount)));
});
test('AC team rate and Pump Repair remain pending instead of guessing a pay split',()=>{
 assert.match(migration,/AC Technician \+ Helper Team ₹437\/hour — Pay Split Pending/);
 assert.match(migration,/Pump Repair — Admin Rate Pending/);
 assert.match(migration,/Basic Electrician \+ Helper — Helper Rate Pending/);
 assert.match(migration,/Above 20 HP — Admin Rate Pending/);
 assert.match(migration,/pending_admin_configuration/);
});
