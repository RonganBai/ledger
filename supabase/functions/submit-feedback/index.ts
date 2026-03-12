import nodemailer from "npm:nodemailer@6.9.16";

import { corsHeaders } from "../_shared/cors.ts";
import {
  createServiceClient,
  ensureUserEnabled,
  quotaDateUtc8,
  requireUser,
} from "../_shared/auth.ts";

const smtpHost = Deno.env.get("FEEDBACK_SMTP_HOST") ?? "smtp.qq.com";
const smtpPort = Number(Deno.env.get("FEEDBACK_SMTP_PORT") ?? "465");
const smtpUsername = Deno.env.get("FEEDBACK_SMTP_USERNAME") ?? "";
const smtpPassword = Deno.env.get("FEEDBACK_SMTP_PASSWORD") ?? "";
const mailFrom = Deno.env.get("FEEDBACK_MAIL_FROM") ?? smtpUsername;
const mailTo = Deno.env.get("FEEDBACK_MAIL_TO") ?? "";

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
    await ensureUserEnabled(user.id);
    const serviceClient = createServiceClient();
    const body = await req.json();
    const content = String(body?.content ?? "").trim();
    const displayName = String(body?.displayName ?? "").trim();
    const maskedEmail = String(body?.maskedEmail ?? "").trim();

    if (!content) {
      return json({ error: "Feedback content is required" }, 400);
    }

    const quotaDate = quotaDateUtc8();
    const { count, error: countError } = await serviceClient
      .from("ledger_feedback_submissions")
      .select("id", { count: "exact", head: true })
      .eq("user_id", user.id)
      .eq("quota_date_utc8", quotaDate);
    if (countError) {
      return json({ error: "Failed to check quota" }, 500);
    }
    if ((count ?? 0) >= 5) {
      return json({ error: "Daily feedback quota exceeded" }, 429);
    }

    const transporter = nodemailer.createTransport({
      host: smtpHost,
      port: smtpPort,
      secure: smtpPort == 465,
      auth: {
        user: smtpUsername,
        pass: smtpPassword,
      },
    });

    const submittedAt = new Date().toISOString();
    const subject = `Ledger Feedback | ${displayName || maskedEmail || user.id}`;
    const text = [
      "Ledger User Feedback",
      "",
      `User ID: ${user.id}`,
      `User Name: ${displayName || maskedEmail || "-"}`,
      `Masked Email: ${maskedEmail || "-"}`,
      `Submitted At: ${submittedAt}`,
      "",
      "Feedback Content:",
      content,
    ].join("\n");

    await transporter.sendMail({
      from: mailFrom,
      to: mailTo,
      subject,
      text,
    });

    const { error: insertError } = await serviceClient
      .from("ledger_feedback_submissions")
      .insert({
        user_id: user.id,
        display_name_snapshot: displayName || maskedEmail || user.id,
        masked_email_snapshot: maskedEmail || "-",
        content,
        quota_date_utc8: quotaDate,
      });
    if (insertError) {
      return json({ error: "Failed to save feedback record" }, 500);
    }

    const remainingCount = 4 - (count ?? 0);
    return json({ remainingCount });
  } catch (error) {
    if (error instanceof Response) {
      return error;
    }
    return json({ error: "Feedback submission failed" }, 500);
  }
});
