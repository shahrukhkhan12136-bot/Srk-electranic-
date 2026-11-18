"use strict";
const { createAiServerGuard } = require("../../lib/ai-server-guard");
exports.handler = createAiServerGuard();
