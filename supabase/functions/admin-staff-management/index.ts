import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, payload: Record<string, unknown>) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "Method not allowed" });

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) return json(500, { error: "Server configuration is incomplete." });

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) return json(401, { error: "Admin login required." });
  const token = authHeader.slice(7);

  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await userClient.auth.getUser(token);
  if (authError || !authData.user) return json(401, { error: "Admin session is invalid or expired." });

  // Never authorize from user_metadata/app_metadata supplied by the browser.
  const { data: isAdmin, error: adminError } = await userClient.rpc("is_srk_admin");
  if (adminError || isAdmin !== true) return json(403, { error: "Main Admin permission required." });

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json(400, { error: "Invalid request body." }); }
  if (body.action !== "invite_support_staff") return json(400, { error: "Unsupported staff action." });

  const email = String(body.email ?? "").trim().toLowerCase();
  const displayName = String(body.display_name ?? "").trim();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254 ||
      displayName.length < 2 || displayName.length > 100) {
    return json(400, { error: "Enter a valid email and a 2–100 character staff name." });
  }

  const service = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Optional server-side redirect; it must also be present in Supabase Auth's redirect allow-list.
  const redirectTo = Deno.env.get("ADMIN_PORTAL_REDIRECT_URL")?.trim();
  if (redirectTo) {
    try {
      const target = new URL(redirectTo);
      if (!["https:", "http:"].includes(target.protocol) ||
          (target.protocol === "http:" && !["localhost", "127.0.0.1"].includes(target.hostname)) ||
          target.username || target.password) {
        return json(500, { error: "ADMIN_PORTAL_REDIRECT_URL must be a trusted HTTPS URL (HTTP is allowed only for localhost)." });
      }
    } catch {
      return json(500, { error: "ADMIN_PORTAL_REDIRECT_URL is invalid." });
    }
  }

  // Role is deliberately fixed here: no client-supplied role can elevate privileges.
  const { data: invited, error: inviteError } = await service.auth.admin.inviteUserByEmail(email, {
    data: { full_name: displayName },
    ...(redirectTo ? { redirectTo } : {}),
  });
  if (inviteError || !invited.user) {
    return json(409, { error: inviteError?.message || "Staff invitation could not be created." });
  }

  const { data: registered, error: registerError } = await service.rpc("srk_admin_staff_register_invited_user", {
    p_staff_user_id: invited.user.id,
    p_display_name: displayName,
    p_actor_admin_id: authData.user.id,
  });
  if (registerError || registered !== true) {
    // The invite has not been delivered as a successful operation. Remove the orphan Auth identity.
    const { error: cleanupError } = await service.auth.admin.deleteUser(invited.user.id);
    return json(500, {
      error: cleanupError
        ? "Staff registry creation failed; the Auth invitation also needs Main Admin review."
        : "Staff registry creation failed; the unregistered Auth identity was removed.",
    });
  }

  return json(200, {
    success: true,
    staff_user_id: invited.user.id,
    role: "support",
    status: "invited",
    message: "Support Staff invitation created. Access remains blocked until Main Admin activates the account.",
  });
});
