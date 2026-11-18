"use strict";

const APP_MODULES = Object.freeze(["customer_support", "booking_assistant", "electrician_assistant"]);
const COPY = Object.freeze({
  customer_support: { title: "AI सहायता", intro: "मैं आपकी SRK ELECTRONIC सहायता और बुकिंग से जुड़े सामान्य सवालों में मदद कर सकता हूँ।", placeholder: "अपना सवाल लिखें…", handoff: "कर्मचारी से सहायता लें" },
  booking_assistant: { title: "बुकिंग सहायता", intro: "मैं सेवा और बुकिंग की जानकारी समझाने तथा बुकिंग का मसौदा तैयार करने में मदद कर सकता हूँ। अंतिम पुष्टि आप करेंगे।", placeholder: "बुकिंग के बारे में पूछें…", handoff: "कर्मचारी से सहायता लें" },
  electrician_assistant: { title: "इलेक्ट्रिशियन सहायता", intro: "मैं आपके अधिकृत काम और सुरक्षित कार्य-मार्गदर्शन से जुड़े सवालों में मदद कर सकता हूँ।", placeholder: "अपना सवाल लिखें…", handoff: "सपोर्ट टीम से सहायता लें" }
});
const ERROR_COPY = Object.freeze({
  authentication_required: "कृपया दोबारा लॉगिन करें।",
  ai_access_denied: "इस सहायता सुविधा की अनुमति उपलब्ध नहीं है।",
  ai_rate_limited: "अभी बहुत अनुरोध आ रहे हैं। थोड़ी देर बाद कोशिश करें।",
  ai_service_unavailable: "AI सहायता अभी उपलब्ध नहीं है। मौजूदा सहायता विकल्प इस्तेमाल करें।",
  ai_not_enabled: "AI सहायता अभी शुरू नहीं की गई है।",
  invalid_ai_response: "उत्तर की पुष्टि नहीं हो सकी। मौजूदा सहायता विकल्प इस्तेमाल करें।"
});

function createAiAssistantWidget({
  container, client, moduleKey, getSession, getContext = () => ({}),
  enabled = false, documentRef = globalThis.document,
  createId = () => globalThis.crypto.randomUUID()
} = {}) {
  if (!enabled) return null;
  if (!container || !documentRef || !APP_MODULES.includes(moduleKey) ||
      !client || typeof client.sendMessage !== "function" ||
      typeof client.createHandoff !== "function" || typeof getSession !== "function") {
    throw new TypeError("invalid_ai_widget_configuration");
  }

  const copy = COPY[moduleKey];
  const root = documentRef.createElement("section");
  root.className = "srk-ai-assistant";
  root.setAttribute("aria-label", copy.title);
  const toggle = documentRef.createElement("button");
  toggle.type = "button";
  toggle.textContent = copy.title;
  toggle.setAttribute("aria-expanded", "false");
  const panel = documentRef.createElement("div");
  panel.hidden = true;
  const heading = documentRef.createElement("h3");
  heading.textContent = copy.title;
  const intro = documentRef.createElement("p");
  intro.textContent = copy.intro;
  const transcript = documentRef.createElement("div");
  transcript.setAttribute("role", "log");
  transcript.setAttribute("aria-live", "polite");
  transcript.setAttribute("aria-relevant", "additions");
  const status = documentRef.createElement("p");
  status.setAttribute("role", "status");
  status.setAttribute("aria-live", "polite");
  const input = documentRef.createElement("textarea");
  input.maxLength = 4000;
  input.rows = 3;
  input.placeholder = copy.placeholder;
  input.setAttribute("aria-label", copy.placeholder);
  const send = documentRef.createElement("button");
  send.type = "button";
  send.textContent = "भेजें";
  const handoffSummary = documentRef.createElement("textarea");
  handoffSummary.maxLength = 1000;
  handoffSummary.rows = 3;
  handoffSummary.placeholder = "कर्मचारी के लिए अपनी समस्या का सार लिखें…";
  handoffSummary.setAttribute("aria-label", handoffSummary.placeholder);
  handoffSummary.hidden = true;
  const handoff = documentRef.createElement("button");
  handoff.type = "button";
  handoff.textContent = copy.handoff;
  handoff.hidden = true;
  panel.append(heading, intro, transcript, input, send, status, handoffSummary, handoff);
  root.append(toggle, panel);
  container.append(root);

  let panelOpen = false;
  function setPanelOpen(open) {
    panelOpen = Boolean(open);
    panel.hidden = !panelOpen;
    toggle.setAttribute("aria-expanded", String(panelOpen));
    if (panelOpen) input.focus();
    else toggle.focus();
  }
  let conversationId = null;
  let busy = false;
  let pendingMessageKey = null;
  let pendingMessageText = null;
  let pendingHandoffKey = null;
  let pendingHandoffSummary = null;
  let destroyed = false;
  let handoffCompleted = false;

  function line(label, value) {
    const p = documentRef.createElement("p");
    const strong = documentRef.createElement("strong");
    strong.textContent = label + ": ";
    const span = documentRef.createElement("span");
    span.textContent = value;
    p.append(strong, span);
    transcript.append(p);
  }
  function showError(error) {
    const code = typeof error?.code === "string" ? error.code : "ai_service_unavailable";
    status.textContent = ERROR_COPY[code] || ERROR_COPY.ai_service_unavailable;
  }
  async function credentials() {
    const session = await getSession();
    const token = session?.access_token;
    if (typeof token !== "string" || !token) {
      const error = new Error("authentication_required");
      error.code = "authentication_required";
      throw error;
    }
    return token;
  }
  async function sendMessage() {
    const message = input.value.trim();
    if (busy || !message || message.length > 4000 || destroyed) return;
    busy = true;
    send.disabled = true;
    status.textContent = "जवाब प्राप्त किया जा रहा है…";
    try {
      if (pendingMessageText !== message || !pendingMessageKey) {
        const nextKey = createId();
        if (typeof nextKey !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}(?![\s\S])/i.test(nextKey)) {
          throw new Error("invalid_idempotency_key");
        }
        pendingMessageKey = nextKey;
        pendingMessageText = message;
      }
      const accessToken = await credentials();
      if (destroyed) return;
      const result = await client.sendMessage({
        moduleKey, message, conversationId, context: getContext(),
        accessToken, idempotencyKey: pendingMessageKey
      });
      if (destroyed) return;
      conversationId = result.conversation_id;
      line("आप", message);
      line("AI उत्तर", result.reply);
      input.value = "";
      pendingMessageKey = null;
      pendingMessageText = null;
      status.textContent = "";
      if (result.handoff?.required === true) {
        handoffSummary.hidden = false;
        handoff.hidden = false;
      }
    } catch (error) {
      if (!destroyed) showError(error);
    } finally {
      busy = false;
      if (!destroyed) send.disabled = false;
    }
  }
  async function requestHandoff() {
    const summary = handoffSummary.value.trim();
    if (busy || !conversationId || !summary || summary.length > 1000 || destroyed) return;
    busy = true;
    handoff.disabled = true;
    status.textContent = "सहायता अनुरोध भेजा जा रहा है…";
    try {
      if (pendingHandoffSummary !== summary || !pendingHandoffKey) {
        const nextKey = createId();
        if (typeof nextKey !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}(?![\s\S])/i.test(nextKey)) {
          throw new Error("invalid_idempotency_key");
        }
        pendingHandoffKey = nextKey;
        pendingHandoffSummary = summary;
      }
      const accessToken = await credentials();
      if (destroyed) return;
      const result = await client.createHandoff({
        moduleKey, conversationId, context: getContext(), summary,
        reasonCode: "needs_human_support", urgency: "normal",
        accessToken, idempotencyKey: pendingHandoffKey
      });
      if (destroyed) return;
      line("सहायता अनुरोध", "दर्ज — " + (result.case_reference || result.handoff_id) + " (" + result.status + ")");
      status.textContent = "आपका सहायता अनुरोध दर्ज हो गया है।";
      pendingHandoffKey = null;
      pendingHandoffSummary = null;
      handoffSummary.disabled = true;
      handoff.disabled = true;
      handoffCompleted = true;
    } catch (error) {
      if (!destroyed) showError(error);
    } finally {
      busy = false;
      if (!destroyed && !handoffCompleted && handoffSummary.value.trim()) handoff.disabled = false;
    }
  }

  const onToggleClick = () => setPanelOpen(!panelOpen);
  const onPanelKeydown = event => {
    if (event.key === "Escape" && panelOpen) {
      event.preventDefault();
      setPanelOpen(false);
    }
  };
  const onInputKeydown = event => {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      sendMessage();
    }
  };
  toggle.addEventListener("click", onToggleClick);
  panel.addEventListener("keydown", onPanelKeydown);
  send.addEventListener("click", sendMessage);
  input.addEventListener("keydown", onInputKeydown);
  handoff.addEventListener("click", requestHandoff);

  return Object.freeze({
    element: root,
    destroy() {
      destroyed = true;
      toggle.removeEventListener("click", onToggleClick);
      panel.removeEventListener("keydown", onPanelKeydown);
      send.removeEventListener("click", sendMessage);
      input.removeEventListener("keydown", onInputKeydown);
      handoff.removeEventListener("click", requestHandoff);
      root.remove();
    }
  });
}

const exported = { APP_MODULES, createAiAssistantWidget };
if (typeof module !== "undefined" && module.exports) module.exports = exported;
if (typeof globalThis !== "undefined") globalThis.SrkAiAssistantWidget = exported;
