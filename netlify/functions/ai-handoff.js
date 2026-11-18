"use strict";
const { createAiServerGuard } = require("../../lib/ai-server-guard");
const guard = createAiServerGuard();
exports.handler = event => guard(event, "handoff");
