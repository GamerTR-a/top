import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// CORS: production'da kendi domaininizi yazın (örn. https://nevgenc.com)
const ALLOWED_ORIGIN = Deno.env.get("ALLOWED_ORIGIN") ?? "https://nevgenc.app";
const CORS = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    // ── 1. Kimlik doğrulama: çağıran gerçekten giriş yapmış mı? ──────────────
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return json({ error: "Yetkisiz: token gerekli." }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const sb = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: userErr } = await sb.auth.getUser();
    if (userErr || !user) {
      return json({ error: "Yetkisiz: geçersiz oturum." }, 401);
    }

    // ── 2. Yetkilendirme: yalnızca admin bildirim gönderebilir ──────────────
    const { data: profile } = await sb
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single();
    if (profile?.role !== "admin") {
      return json({ error: "Bu işlem için admin yetkisi gerekir." }, 403);
    }

    // ── 3. Girdi doğrulama ──────────────────────────────────────────────────
    const { subject, message } = await req.json();
    const subjStr = String(subject ?? "").trim();
    const msgStr = String(message ?? "").trim();
    if (!subjStr || !msgStr) {
      return json({ error: "Konu ve mesaj boş olamaz." }, 400);
    }
    if (subjStr.length > 200 || msgStr.length > 5000) {
      return json({ error: "Konu (≤200) veya mesaj (≤5000) çok uzun." }, 400);
    }

    const apiKey = Deno.env.get("RESEND_API_KEY");
    if (!apiKey) return json({ error: "RESEND_API_KEY ayarlanmamış" }, 500);

    const zaman = new Date().toLocaleString("tr-TR", { timeZone: "Europe/Istanbul" });

    // HTML karakterleri kaçır, satır sonlarını <br> yap
    const esc = (s: string) =>
      s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    const safeSubject = esc(subjStr);
    const safeMsg = esc(msgStr).replace(/\n/g, "<br>");

    const html = `
      <div style="font-family:Inter,sans-serif;max-width:600px;margin:0 auto;background:#0f172a;color:#e2e8f0;border-radius:12px;overflow:hidden;">
        <div style="background:linear-gradient(135deg,#6366f1,#8b5cf6);padding:24px 28px;">
          <h1 style="margin:0;font-size:20px;font-weight:700;color:#fff;">🔔 NevGenç Bildirim</h1>
          <p style="margin:4px 0 0;color:rgba(255,255,255,.75);font-size:13px;">${zaman}</p>
        </div>
        <div style="padding:28px;">
          <h2 style="font-size:15px;margin:0 0 14px;color:#a5b4fc;">${safeSubject}</h2>
          <div style="background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.08);border-radius:8px;padding:18px;font-size:14px;line-height:1.75;">${safeMsg}</div>
        </div>
        <div style="padding:0 28px 20px;font-size:12px;color:#4b5563;">NevGenç Otomatik Bildirim Sistemi</div>
      </div>`;

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
      body: JSON.stringify({
        from: "NevGenç <onboarding@resend.dev>",
        to: ["nevgenc54@gmail.com"],
        subject: `[NevGenç] ${subjStr}`,
        html,
      }),
    });

    if (!res.ok) return json({ error: await res.text() }, 500);
    return json({ ok: true });
  } catch (err) {
    return json({ error: String(err) }, 500);
  }
});
