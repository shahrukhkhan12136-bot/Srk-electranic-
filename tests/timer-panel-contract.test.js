const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const read = file => fs.readFileSync(path.join(__dirname, "..", file), "utf8");

const customer = read("index.html");
const electrician = read("electrician.html");
const admin = read("admin.html");
const staffReadme = read("staff/README.md");
const customerAndroid = read("apps/customer-android/README.md");
const electricianAndroid = read("apps/electrician-android/README.md");

function requireTokens(source, tokens, label) {
  for (const token of tokens) assert.ok(source.includes(token), label + " missing: " + token);
}
function ordered(source, first, second, label) {
  const a = source.indexOf(first), b = source.indexOf(second);
  assert.ok(a >= 0 && b > a, label + " must occur before privileged write");
}

// Customer and Electrician have their own timer workflows and server RPC actions.
requireTokens(customer, [
  "customerTimerCardHtml", "customerTimerDecision",
  "customerCreatePayableSnapshot", "customerPaySnapshot",
  "customerSelectCashPayment", "customerDecideMaterialRevision"
], "Customer timer UI");
requireTokens(electrician, [
  "electricianTimerCardHtml", "electricianTimerAction",
  "electricianMaterialFormHtml", "electricianConfirmSnapshotCash"
], "Electrician timer UI");

// Admin timer view is explicitly an audit view; generic Save must stop before writes.
requireTokens(admin, ["renderTimerAdmin", "केवल ऑडिट दृश्य"], "Admin timer audit");
const saveStart = admin.indexOf("async function saveBooking(id)");
assert.ok(saveStart >= 0, "Admin generic save handler exists");
const saveBody = admin.slice(saveStart, admin.indexOf("\n}", saveStart) + 2);
ordered(saveBody, "if(booking.service_category_code)", "const quoted=", "Admin timer guard");
requireTokens(saveBody, ["पुराने Admin Save", "return;"], "Admin timer write guard");

// Staff and native Android workspaces are still declared scaffolds, not completed apps.
requireTokens(staffReadme, ["README-only scaffold", "कोई live Staff login"], "Staff scope disclosure");
requireTokens(customerAndroid, ["README-only scaffold", "कोई installable app"], "Customer Android scope disclosure");
requireTokens(electricianAndroid, ["README-only scaffold", "कोई installable app"], "Electrician Android scope disclosure");


// Contact privacy: full phone numbers are exposed only after the accepted
// assignment marker exists; the customer-side lookup remains available after completion.
const offerRpc = read("supabase/migrations/20261112120000_electrician_offer_order_number_rpc.sql");
const customerContactMigration = read("supabase/migrations/20261111160014_keep_customer_call_contact_after_completion.sql");
requireTokens(offerRpc, [
  "case when b.assigned_electrician_id = p.id",
  "then b.phone else null end",
  "'assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed'"
], "Electrician post-acceptance customer contact gate");
requireTokens(customerContactMigration, [
  "where b.customer_user_id = v_uid",
  "and b.assigned_electrician_id is not null"
], "Customer post-acceptance electrician contact gate");
requireTokens(electrician, [
  "o.customer_phone",
  "ग्राहक मोबाइल:",
  "☎ ग्राहक को कॉल करें"
], "Electrician accepted-booking call UI");
requireTokens(customer, [
  "srk_get_customer_call_contacts",
  "contact?.electrician_phone",
  "☎ इलेक्ट्रिशियन को कॉल करें"
], "Customer accepted-booking call UI");
assert.ok(!/then b\.phone else null end[\s\S]{0,500}where b\.assigned_electrician_id = p\.id/.test(offerRpc),
  "Electrician contact query must not expose customer phone without the assigned-electrician identity gate");

console.log("Panel contract tests passed (Customer/Electrician timer UI, Admin timer write guard, and scaffold status disclosure).");
