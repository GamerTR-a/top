import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return json({ error: "Yetkisiz: token gerekli." }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!serviceKey) return json({ error: "SERVICE_ROLE_KEY ayarlanmamış" }, 500);

    // ── 1. Çağıranın kimliğini ve admin rolünü doğrula (anon client + JWT) ──
    const caller = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: userErr } = await caller.auth.getUser();
    if (userErr || !user) return json({ error: "Yetkisiz: geçersiz oturum." }, 401);

    const { data: callerProfile } = await caller
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single();
    if (callerProfile?.role !== "admin") {
      return json({ error: "Bu işlem için admin yetkisi gerekir." }, 403);
    }

    // ── 2. Girdi ──────────────────────────────────────────────────────────
    const { userId } = await req.json();
    if (!userId || typeof userId !== "string") {
      return json({ error: "userId gerekli." }, 400);
    }
    if (userId === user.id) {
      return json({ error: "Kendi hesabınızı silemezsiniz." }, 400);
    }

    // ── 3. Service-role ile hem auth.users hem (cascade) profiles sil ──────
    const admin = createClient(supabaseUrl, serviceKey);
    const { error: delErr } = await admin.auth.admin.deleteUser(userId);
    if (delErr) {
      // İç hata detayını yalnızca sunucu loguna yaz — client'a genel mesaj dön
      // (bkz. güvenlik denetimi: "iç detay sızdıran hata mesajları").
      console.error("delete-user: admin.deleteUser failed", delErr);
      // auth kaydı yoksa yine de profiles satırını temizlemeyi dene
      await admin.from("profiles").delete().eq("id", userId);
      return json({ error: "Kullanıcı silinemedi. Lütfen tekrar deneyin." }, 500);
    }
    // FK cascade yoksa profiles satırı kalmış olabilir — garanti için sil
    await admin.from("profiles").delete().eq("id", userId);

    return json({ ok: true });
  } catch (err) {
    console.error("delete-user: unhandled error", err);
    return json({ error: "Beklenmeyen bir hata oluştu." }, 500);
  }
});
