// ============================================================================
// send-community-notification — Görev 5: Başkan'ın kendi topluluğundaki
// üyelere bildirim göndermesi.
// ----------------------------------------------------------------------------
// Yetki modeli (SUNUCU TARAFINDA zorlanır — istemci kontrolü tek başına asla
// güvenilmez):
//   - role = 'admin'  -> herhangi bir topluluğa gönderebilir.
//   - role = 'baskan' -> yalnızca communities.chairman_id = kendi id'si olan
//                        topluluğa gönderebilir.
//   - recipient_ids  -> gönderilecekse, HER biri gerçekten o topluluğun
//                        (community_members) üyesi olmalı; olmayanlar sessizce
//                        elenir (başka bir kullanıcıya sızıntı önlenir).
//   - audience = "all" -> YALNIZCA admin: tüm kullanıcılara duyuru
//                        (type='announcement'); community_id gerekmez.
//
// Yapılanlar:
//   1) `notifications` tablosuna her alıcı için satır eklenir (uygulama içi
//      bildirim merkezinde görünür — mevcut sendUpdateAnnouncement ile aynı şema).
//   2) `community_notifications` tablosuna tek bir audit/log kaydı eklenir.
//   3) Alıcıların `fcm_tokens` kayıtlarına GERÇEK bir FCM push gönderilir
//      (uygulama kapalıyken de bildirim ulaşsın diye) — Firebase HTTP v1 API,
//      servis hesabı ile OAuth2 JWT bearer akışı kullanılarak çağrılır.
//      FCM_SERVICE_ACCOUNT_JSON secret'ı ayarlanmamışsa bu adım atlanır,
//      yalnızca uygulama-içi bildirim eklenir (hata fırlatılmaz).
// ============================================================================

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

// ── FCM HTTP v1: servis hesabıyla OAuth2 JWT bearer akışı ──────────────────

function base64UrlEncode(data: Uint8Array | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  let binary = "";
  bytes.forEach((b) => (binary += String.fromCharCode(b)));
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToPkcs8(pem: string): ArrayBuffer {
  const clean = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const binary = atob(clean);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

async function getFcmAccessToken(serviceAccount: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  const header = { alg: "RS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const signingInput =
    `${base64UrlEncode(JSON.stringify(header))}.${base64UrlEncode(JSON.stringify(claim))}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(serviceAccount.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput),
  );
  const jwt = `${signingInput}.${base64UrlEncode(new Uint8Array(signature))}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) {
    throw new Error(`FCM OAuth token alınamadı: ${await res.text()}`);
  }
  const data = await res.json();
  return data.access_token as string;
}

/// Tek bir token'a push gönderir. Token geçersizse (UNREGISTERED/NOT_FOUND)
/// çağıran taraf `fcm_tokens` kaydını temizleyebilsin diye geri bildirir.
async function sendToToken(
  projectId: string,
  accessToken: string,
  token: string,
  title: string,
  body: string,
  type: string,
): Promise<{ ok: boolean; invalid: boolean }> {
  try {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body },
            data: { type },
            android: { notification: { channel_id: "nevgenc_general" } },
          },
        }),
      },
    );
    if (res.ok) return { ok: true, invalid: false };
    const errText = await res.text();
    const invalid = errText.includes("UNREGISTERED") || errText.includes("NOT_FOUND");
    return { ok: false, invalid };
  } catch {
    return { ok: false, invalid: false };
  }
}

// deno-lint-ignore no-explicit-any
type AdminClient = any;

/// Tablo satırlarını 1000'lik sayfalar hâlinde okur (PostgREST max-rows).
async function selectAll<T>(
  build: (from: number, to: number) => PromiseLike<{ data: T[] | null; error: unknown }>,
): Promise<T[]> {
  const out: T[] = [];
  const page = 1000;
  for (let from = 0; ; from += page) {
    const { data, error } = await build(from, from + page - 1);
    if (error) throw error;
    out.push(...(data ?? []));
    if (!data || data.length < page) break;
  }
  return out;
}

/// FCM push gönderir (secret yoksa sessizce 0 döner). userIds null ise
/// kayıtlı tüm token'lara gönderilir.
async function sendPushes(
  admin: AdminClient,
  userIds: string[] | null,
  title: string,
  body: string,
  type: string,
): Promise<number> {
  const serviceAccountRaw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  if (!serviceAccountRaw) return 0;
  let pushSent = 0;
  try {
    const serviceAccount = JSON.parse(serviceAccountRaw);
    const accessToken = await getFcmAccessToken(serviceAccount);

    const tokenRows = await selectAll<{ token: string }>((from, to) => {
      let q = admin.from("fcm_tokens").select("token");
      if (userIds) q = q.in("user_id", userIds);
      return q.range(from, to);
    });
    const tokens = Array.from(new Set(tokenRows.map((r) => r.token)));

    const invalidTokens: string[] = [];
    // FCM'e aynı anda binlerce istek atmamak için 100'lük gruplar.
    for (let i = 0; i < tokens.length; i += 100) {
      const chunk = tokens.slice(i, i + 100);
      const results = await Promise.allSettled(
        chunk.map((t) =>
          sendToToken(serviceAccount.project_id, accessToken, t, title, body, type)
        ),
      );
      results.forEach((r, j) => {
        if (r.status === "fulfilled") {
          if (r.value.ok) pushSent++;
          if (r.value.invalid) invalidTokens.push(chunk[j]);
        }
      });
    }
    if (invalidTokens.length > 0) {
      await admin.from("fcm_tokens").delete().in("token", invalidTokens);
    }
  } catch (e) {
    console.error("[send-community-notification] FCM push hatası:", e);
    // Push başarısız olsa da uygulama-içi bildirim zaten kaydedildi.
  }
  return pushSent;
}

async function insertNotifications(
  admin: AdminClient,
  rows: Record<string, unknown>[],
): Promise<string | null> {
  for (let i = 0; i < rows.length; i += 500) {
    const { error } = await admin.from("notifications").insert(rows.slice(i, i + 500));
    if (error) return error.message;
  }
  return null;
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    // ── 1. Kimlik doğrulama ────────────────────────────────────────────────
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return json({ error: "Yetkisiz: token gerekli." }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: userErr } = await callerClient.auth.getUser();
    if (userErr || !user) {
      return json({ error: "Yetkisiz: geçersiz oturum." }, 401);
    }

    // ── 2. Girdi doğrulama ──────────────────────────────────────────────────
    const payload = await req.json();
    const isBroadcast = payload?.audience === "all";
    const communityId = Number(payload?.community_id);
    const title = String(payload?.title ?? "").trim();
    const body = String(payload?.body ?? "").trim();
    const requestedRecipientIds: string[] | null = Array.isArray(payload?.recipient_ids)
      ? payload.recipient_ids.map((v: unknown) => String(v))
      : null;

    if (!isBroadcast && !Number.isFinite(communityId)) {
      return json({ error: "Geçersiz community_id." }, 400);
    }
    if (!title || title.length > 80) {
      return json({ error: "Başlık zorunlu ve en fazla 80 karakter olmalı." }, 400);
    }
    if (!body || body.length > (isBroadcast ? 2000 : 500)) {
      return json({ error: "Mesaj zorunlu ve çok uzun olmamalı." }, 400);
    }

    // Servis rolü ile çalışan admin client — RLS'i atlayarak yetki kontrolü
    // ve gönderim işlemlerini güvenli biçimde yürütür.
    const admin = createClient(supabaseUrl, serviceRoleKey);

    // ── 2b. Tüm kullanıcılara duyuru (yalnızca admin) ──────────────────────
    if (isBroadcast) {
      const { data: callerProfile } = await admin
        .from("profiles")
        .select("role")
        .eq("id", user.id)
        .single();
      if (callerProfile?.role !== "admin") {
        return json({ error: "Bu işlem için admin yetkisi gerekir." }, 403);
      }
      const extra = payload?.data && typeof payload.data === "object" ? payload.data : {};
      const allIds = (await selectAll<{ id: string }>((from, to) =>
        admin.from("profiles").select("id").range(from, to)
      )).map((p) => p.id);
      const nowIso = new Date().toISOString();
      const broadcastErr = await insertNotifications(
        admin,
        allIds.map((uid) => ({
          user_id: uid,
          title,
          body,
          type: "announcement",
          data: {
            version: extra.version ?? null,
            store_url: extra.store_url ?? null,
            is_update: extra.is_update === true,
          },
          is_read: false,
          created_at: nowIso,
        })),
      );
      if (broadcastErr) {
        return json({ error: `Bildirimler kaydedilemedi: ${broadcastErr}` }, 500);
      }
      const broadcastPush = await sendPushes(admin, null, title, body, "announcement");
      return json({ ok: true, sent_count: allIds.length, push_sent: broadcastPush });
    }

    // ── 3. Yetkilendirme: admin HERHANGİ topluluğa, başkan SADECE kendi
    //     topluluğuna gönderebilir ──────────────────────────────────────────
    const { data: profile, error: profileErr } = await admin
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single();
    if (profileErr || !profile) {
      return json({ error: "Profil bulunamadı." }, 403);
    }

    const { data: community, error: communityErr } = await admin
      .from("communities")
      .select("id, chairman_id")
      .eq("id", communityId)
      .single();
    if (communityErr || !community) {
      return json({ error: "Topluluk bulunamadı." }, 404);
    }

    const isAdmin = profile.role === "admin";
    const isChairmanOfThisCommunity =
      profile.role === "baskan" && community.chairman_id === user.id;
    if (!isAdmin && !isChairmanOfThisCommunity) {
      return json(
        { error: "Bu topluluğa bildirim gönderme yetkiniz yok." },
        403,
      );
    }

    // ── 4. Alıcıları belirle: gerçek topluluk üyeleriyle kesişim al ────────
    const { data: memberRows, error: memberErr } = await admin
      .from("community_members")
      .select("user_id")
      .eq("community_id", communityId);
    if (memberErr) {
      return json({ error: "Üyeler alınamadı." }, 500);
    }
    const memberIds = new Set((memberRows ?? []).map((m: { user_id: string }) => m.user_id));

    let recipientIds: string[];
    if (requestedRecipientIds && requestedRecipientIds.length > 0) {
      // Sadece gerçekten bu topluluğun üyesi olanlar — başka bir kullanıcıya
      // sızıntıyı (ör. üye olmayan bir id gönderilirse) önler.
      recipientIds = requestedRecipientIds.filter((id) => memberIds.has(id));
    } else {
      recipientIds = Array.from(memberIds);
    }

    if (recipientIds.length === 0) {
      return json({ error: "Geçerli alıcı bulunamadı." }, 400);
    }

    // ── 5. Uygulama-içi bildirim kayıtları ──────────────────────────────────
    const nowIso = new Date().toISOString();
    const notificationRows = recipientIds.map((uid) => ({
      user_id: uid,
      title,
      body,
      type: "community",
      data: { community_id: communityId },
      is_read: false,
      created_at: nowIso,
    }));
    const insertErr = await insertNotifications(admin, notificationRows);
    if (insertErr) {
      return json({ error: `Bildirimler kaydedilemedi: ${insertErr}` }, 500);
    }

    // ── 6. Audit log ────────────────────────────────────────────────────────
    await admin.from("community_notifications").insert({
      community_id: communityId,
      sender_id: user.id,
      title,
      body,
      recipient_count: recipientIds.length,
    });

    // ── 7. Gerçek FCM push (opsiyonel — secret yoksa sessizce atlanır) ─────
    const pushSent = await sendPushes(
      admin,
      recipientIds,
      title,
      body,
      "community_notification",
    );

    return json({
      ok: true,
      sent_count: recipientIds.length,
      push_sent: pushSent,
    });
  } catch (err) {
    return json({ error: String(err) }, 500);
  }
});
