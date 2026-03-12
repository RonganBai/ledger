import { createClient } from "jsr:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

export function createUserClient(authHeader: string | null) {
  if (!authHeader) {
    throw new Response(JSON.stringify({ error: "Missing authorization" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  return createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: {
        Authorization: authHeader,
      },
    },
  });
}

export function createServiceClient() {
  return createClient(supabaseUrl, supabaseServiceRoleKey);
}

export async function requireUser(authHeader: string | null) {
  const userClient = createUserClient(authHeader);
  const {
    data: { user },
    error,
  } = await userClient.auth.getUser();
  if (error || !user) {
    throw new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }
  return user;
}

export async function ensureUserEnabled(userId: string) {
  const serviceClient = createServiceClient();
  const { data, error } = await serviceClient
    .from("ledger_user_admin_state")
    .select("is_disabled")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) {
    throw new Response(JSON.stringify({ error: "Failed to verify user state" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
  if (data?.is_disabled === true) {
    throw new Response(JSON.stringify({ error: "User disabled" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }
}

export async function requireAdmin(userId: string) {
  const serviceClient = createServiceClient();
  const { data, error } = await serviceClient
    .from("ledger_admins")
    .select("user_id")
    .eq("user_id", userId)
    .eq("is_active", true)
    .maybeSingle();
  if (error || !data) {
    throw new Response(JSON.stringify({ error: "Forbidden" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }
  return serviceClient;
}

export function quotaDateUtc8(now = new Date()) {
  const shifted = new Date(now.getTime() + 8 * 60 * 60 * 1000);
  return shifted.toISOString().slice(0, 10);
}

export function maskEmail(email: string) {
  const at = email.indexOf("@");
  if (at <= 0 || at >= email.length - 1) return email;
  const local = email.slice(0, at);
  const domain = email.slice(at);
  if (local.length <= 2) {
    return `${local[0]}*${local.length === 2 ? local[1] : ""}${domain}`;
  }
  return `${local[0]}${"*".repeat(local.length - 2)}${
    local[local.length - 1]
  }${domain}`;
}
