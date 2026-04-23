// @ts-nocheck — This file runs on Supabase Deno runtime, not Node.js
// supabase/functions/push-notification/index.ts
// Supabase Edge Function: Send FCM Push Notification
// يتم استدعاؤها تلقائياً عند إضافة إشعار جديد في جدول notifications

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ============================================================================
// Firebase Auth: Get Access Token using Service Account
// ============================================================================

interface ServiceAccount {
  project_id: string;
  private_key: string;
  client_email: string;
}

/**
 * Generate a JWT and exchange it for a Google OAuth2 access token
 * Required for FCM HTTP v1 API
 */
async function getAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  };

  // Encode header and payload
  const encoder = new TextEncoder();
  const headerB64 = btoa(JSON.stringify(header))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
  const payloadB64 = btoa(JSON.stringify(payload))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  const signingInput = `${headerB64}.${payloadB64}`;

  // Import the private key and sign
  const pemContents = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "");
  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    encoder.encode(signingInput)
  );

  const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  const jwt = `${signingInput}.${signatureB64}`;

  // Exchange JWT for access token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenResponse.json();
  if (!tokenData.access_token) {
    throw new Error(`Failed to get access token: ${JSON.stringify(tokenData)}`);
  }

  return tokenData.access_token;
}

// ============================================================================
// FCM: Send Push Notification
// ============================================================================

interface FCMMessage {
  token: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

/**
 * Send a push notification via FCM HTTP v1 API
 */
async function sendFCMNotification(
  accessToken: string,
  projectId: string,
  message: FCMMessage
): Promise<{ success: boolean; error?: string }> {
  try {
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: message.token,
            notification: {
              title: message.title,
              body: message.body,
            },
            data: message.data || {},
            android: {
              priority: "high",
              notification: {
                channel_id: "ell_tall_market",
                sound: "default",
                default_vibrate_timings: true,
                default_light_settings: true,
                notification_priority: "PRIORITY_HIGH",
                visibility: "PUBLIC",
              },
            },
            apns: {
              payload: {
                aps: {
                  alert: {
                    title: message.title,
                    body: message.body,
                  },
                  sound: "default",
                  badge: 1,
                  "content-available": 1,
                },
              },
              headers: {
                "apns-priority": "10",
              },
            },
          },
        }),
      }
    );

    if (response.ok) {
      return { success: true };
    }

    const errorBody = await response.text();
    console.error(`FCM Error [${response.status}]: ${errorBody}`);

    // If token is invalid, mark it for cleanup
    if (
      response.status === 404 ||
      errorBody.includes("UNREGISTERED") ||
      errorBody.includes("INVALID_ARGUMENT")
    ) {
      return { success: false, error: "invalid_token" };
    }

    return { success: false, error: errorBody };
  } catch (error) {
    console.error("FCM send error:", error);
    return { success: false, error: String(error) };
  }
}

// ============================================================================
// Main Handler
// ============================================================================

serve(async (req: Request) => {
  try {
    // Only accept POST
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), {
        status: 405,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Parse request body
    let body: any;
    let record: any;
    
    try {
      const text = await req.text();
      if (text.trim().length === 0) {
        return new Response(JSON.stringify({ error: "Empty body" }), {
          status: 400,
          headers: { "Content-Type": "application/json" },
        });
      }
      body = JSON.parse(text);
      // Handle both direct record and wrapped record (webhook vs trigger)
      record = body.record || body;
    } catch (error) {
      console.error("❌ Failed to parse body:", error);
      return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Support: store_id (merchant), user_id+target_role (admin/captain/client)
    const storeId = record.store_id;
    const userId = record.user_id;
    const targetRole = record.target_role || "client";
    
    if (!storeId && !userId) {
      return new Response(JSON.stringify({ error: "No store_id or user_id in record" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }
    const title = record.title;
    const notifBody = record.body;
    const data = record.data || {};

    if (!title) {
      return new Response(
        JSON.stringify({ error: "Missing title" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const targetType = storeId ? "store" : `user(${targetRole})`;
    const targetId = storeId || userId;
    console.log(`📨 Sending push to ${targetType} ${targetId}: "${title}"`);

    // Get Firebase service account from Supabase secrets
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountJson) {
      throw new Error("FIREBASE_SERVICE_ACCOUNT secret not configured");
    }
    
    const serviceAccount: ServiceAccount = JSON.parse(serviceAccountJson);

    // Get Supabase client (service role for reading device_tokens)
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // ============================================================
    // Role-based token routing:
    // - store_id → device_tokens WHERE store_id = X (merchant)
    // - user_id + target_role → device_tokens WHERE client_id = X AND role = Y
    // This ensures a merchant doesn't get admin notifications, etc.
    // ============================================================
    let tokensQuery = supabase
      .from("device_tokens")
      .select("token, platform");
    
    if (storeId) {
      // Store notification → find tokens registered for this store
      tokensQuery = tokensQuery.eq("store_id", storeId);
    } else if (userId && targetRole) {
      // Role-specific notification → find tokens for user + role
      tokensQuery = tokensQuery.eq("client_id", userId).eq("role", targetRole);
    } else {
      // Fallback → find all tokens for user
      tokensQuery = tokensQuery.eq("client_id", userId);
    }

    const { data: tokens, error: tokensError } = await tokensQuery;

    if (tokensError) {
      throw new Error(`Failed to fetch tokens: ${tokensError.message}`);
    }

    if (!tokens || tokens.length === 0) {
      console.log(`⚠️ No device tokens found for ${targetType} ${targetId}`);
      return new Response(
        JSON.stringify({ success: true, sent: 0, message: "No tokens" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    console.log(`📱 Found ${tokens.length} device token(s) for ${targetType} ${targetId}`);

    // Deduplicate tokens (same physical device may have been registered multiple times)
    const uniqueTokens = [...new Map(tokens.map((t: any) => [t.token, t])).values()];
    if (uniqueTokens.length < tokens.length) {
      console.log(`🔄 Deduplicated: ${tokens.length} → ${uniqueTokens.length} unique token(s)`);
    }

    // Get FCM access token
    const accessToken = await getAccessToken(serviceAccount);

    // Convert notification data to string values (FCM data must be string-only)
    const stringData: Record<string, string> = {};
    for (const [key, value] of Object.entries(data)) {
      stringData[key] = typeof value === "string" ? value : JSON.stringify(value);
    }
    // Add notification ID for tracking
    if (record.id) stringData["notification_id"] = record.id;

    // Send to all device tokens
    let sent = 0;
    let failed = 0;
    const invalidTokens: string[] = [];

    for (const tokenRecord of uniqueTokens) {
      const result = await sendFCMNotification(
        accessToken,
        serviceAccount.project_id,
        {
          token: tokenRecord.token,
          title,
          body: notifBody || "",
          data: stringData,
        }
      );

      if (result.success) {
        sent++;
      } else {
        failed++;
        if (result.error === "invalid_token") {
          invalidTokens.push(tokenRecord.token);
        }
      }
    }

    // Cleanup invalid tokens
    if (invalidTokens.length > 0) {
      console.log(`🗑️ Cleaning up ${invalidTokens.length} invalid token(s)`);
      await supabase
        .from("device_tokens")
        .delete()
        .in("token", invalidTokens);
    }

    console.log(`✅ Push sent: ${sent} success, ${failed} failed`);

    return new Response(
      JSON.stringify({ success: true, sent, failed }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("❌ Edge Function error:", error);
    return new Response(
      JSON.stringify({ error: String(error) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
