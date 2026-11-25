import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const source = readFileSync(new URL('../apps/electrician_app/lib/main.dart', import.meta.url), 'utf8');

test('Technician dashboard reads its own server-authoritative payment cycle', () => {
  assert.match(source, /client\.rpc\('srk_worker_get_my_payment_cycle'\)/);
  assert.match(source, /completed_booking_count/);
  assert.match(source, /next_sequence_number/);
  assert.match(source, /next_booking_requires_online/);
});

test('Technician dashboard explains mandatory online payment on third and every third booking', () => {
  assert.match(source, /मेरा भुगतान चक्र/);
  assert.match(source, /केवल Online भुगतान स्वीकार होगा/);
  assert.match(source, /Cash विकल्प सर्वर पर भी बंद रहेगा/);
  assert.match(source, /Cash या Online/);
});

test('Technician client does not calculate or override the payment sequence locally', () => {
  assert.doesNotMatch(source, /mod\s*\([^)]*sequence/i);
  assert.doesNotMatch(source, /srk_technician_booking_sequence/);
  assert.doesNotMatch(source, /srk_helper_booking_sequence/);
});
