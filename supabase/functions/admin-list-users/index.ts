import { corsHeaders } from "../_shared/cors.ts";
import {
  createServiceClient,
  maskEmail,
  requireAdmin,
  requireUser,
} from "../_shared/auth.ts";

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
  if (req.method !== "POST" && req.method !== "GET") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const user = await requireUser(req.headers.get("Authorization"));
    const serviceClient = await requireAdmin(user.id);
    const {
      data: { users },
      error: listError,
    } = await serviceClient.auth.admin.listUsers({
      page: 1,
      perPage: 1000,
    });
    if (listError) {
      return json({ error: "Failed to list users" }, 500);
    }

    const userIds = users.map((item) => item.id);
    const { data: publicProfiles } = await serviceClient
      .from("ledger_user_public_profiles")
      .select("user_id,display_name");
    const { data: admins } = await serviceClient
      .from("ledger_admins")
      .select("user_id,is_active");

    const profileMap = new Map(
      (publicProfiles ?? []).map((item) => [item.user_id, item.display_name]),
    );
    const adminMap = new Map(
      (admins ?? []).map((item) => [item.user_id, item.is_active === true]),
    );

    const items = users
      .filter((item) => userIds.includes(item.id))
      .map((item) => {
        const email = item.email ?? "";
        return {
          userId: item.id,
          displayName: profileMap.get(item.id) ?? email,
          maskedEmail: maskEmail(email),
          isAdmin: adminMap.get(item.id) == true,
          isActive: adminMap.get(item.id) != false,
          createdAt: item.created_at,
        };
      });

    return json({ users: items });
  } catch (error) {
    if (error instanceof Response) {
      return error;
    }
    return json({ error: "Failed to fetch admin users" }, 500);
  }
});
