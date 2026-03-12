import { corsHeaders } from "../_shared/cors.ts";
import { requireAdmin, requireUser } from "../_shared/auth.ts";

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const user = await requireUser(req.headers.get("Authorization"));
    const serviceClient = await requireAdmin(user.id);
    const body = await req.json();
    const targetUserId = String(body?.targetUserId ?? "").trim();
    if (!targetUserId) {
      return json({ error: "targetUserId is required" }, 400);
    }

    const { error } = await serviceClient.from("ledger_admins").upsert({
      user_id: targetUserId,
      is_active: true,
      updated_at: new Date().toISOString(),
    });
    if (error) {
      return json({ error: "Failed to update admin role" }, 500);
    }
    return json({ ok: true });
  } catch (error) {
    if (error instanceof Response) {
      return error;
    }
    return json({ error: "Failed to grant admin role" }, 500);
  }
});
