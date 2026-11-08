// Netlify adapter for the existing root-level booking handler.
// Booking dispatch logic will be reconciled in the next project phase.
const { handler } = require("../../create-booking.js");
exports.handler = handler;
