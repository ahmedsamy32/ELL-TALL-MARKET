// @ts-nocheck — This file runs on Supabase Deno runtime, not Node.js
// supabase/functions/merchant-wallet/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing Authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") || "";
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

    // Authenticate user with their own token for RLS validation
    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    // Admin client to bypass RLS for administrative actions (e.g. topups, cron)
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey);

    // Get current user profile and role
    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser();

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized user token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Fetch user profile role
    const { data: profile, error: profileError } = await supabaseAdmin
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single();

    if (profileError || !profile) {
      return new Response(
        JSON.stringify({ error: "Failed to fetch user profile role" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const userRole = profile.role;
    const url = new URL(req.url);
    const path = url.pathname.replace(/\/+$/, "");

    // =========================================================================
    // ENDPOINT: POST /subscribe
    // =========================================================================
    if (path.endsWith("/subscribe") && req.method === "POST") {
      const { tier_id, merchant_id } = await req.json();

      // Determine target merchant ID: merchants can only subscribe themselves; admins can subscribe anyone.
      const targetMerchantId = userRole === "admin" ? merchant_id : user.id;

      if (!targetMerchantId) {
        return new Response(
          JSON.stringify({ error: "Missing merchant_id" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Fetch subscription tier details
      const { data: tier, error: tierError } = await supabaseAdmin
        .from("subscription_tiers")
        .select("*")
        .eq("id", tier_id)
        .single();

      if (tierError || !tier) {
        return new Response(
          JSON.stringify({ error: "Subscription tier not found" }),
          { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Fetch merchant details
      const { data: merchant, error: merchantError } = await supabaseAdmin
        .from("merchants")
        .select("*")
        .eq("id", targetMerchantId)
        .single();

      if (merchantError || !merchant) {
        return new Response(
          JSON.stringify({ error: "Merchant not found" }),
          { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Verify wallet balance covers tier price
      const price = parseFloat(tier.monthly_price);
      const balance = parseFloat(merchant.wallet_balance);

      if (balance < price) {
        return new Response(
          JSON.stringify({ error: `Insufficient wallet balance (${balance} EGP) to subscribe to ${tier.name} tier (${price} EGP).` }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Perform transaction (Deduct, Update subscription details, Add transaction history)
      const newBalance = balance - price;
      const newExpiry = new Date();
      newExpiry.setDate(newExpiry.getDate() + 30); // 30 days expiry

      // Update merchant record using admin client to set balance and fields safely
      const { error: updateError } = await supabaseAdmin
        .from("merchants")
        .update({
          wallet_balance: newBalance,
          current_tier_id: tier.id,
          package_expiry_date: newExpiry.toISOString(),
          remaining_orders: tier.included_orders !== null ? tier.included_orders : 999999, // default large number for Unlimited
          overlimit_orders_count: 0,
          status: "active",
          updated_at: new Date().toISOString(),
        })
        .eq("id", targetMerchantId);

      if (updateError) {
        return new Response(
          JSON.stringify({ error: "Failed to update merchant subscription details: " + updateError.message }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Insert transaction history record
      await supabaseAdmin.from("wallet_transactions").insert({
        merchant_id: targetMerchantId,
        amount: price,
        type: "debit",
        description: `Subscribed to ${tier.name} Tier (${price} EGP)`,
      });

      return new Response(
        JSON.stringify({
          success: true,
          message: `Successfully subscribed to ${tier.name} tier.`,
          wallet_balance: newBalance,
          expiry_date: newExpiry,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // =========================================================================
    // ENDPOINT: POST /topup
    // =========================================================================
    if (path.endsWith("/topup") && req.method === "POST") {
      const { merchant_id, amount, notes } = await req.json();

      if (!merchant_id || !amount || amount <= 0) {
        return new Response(
          JSON.stringify({ error: "Invalid merchant_id or top-up amount" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Check if user is authorized to perform top-up (Admins only, or merchants topping up themselves for testing)
      if (userRole !== "admin" && user.id !== merchant_id) {
        return new Response(
          JSON.stringify({ error: "Forbidden: You are not authorized to perform wallet top-ups." }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Fetch merchant details
      const { data: merchant, error: merchantError } = await supabaseAdmin
        .from("merchants")
        .select("*")
        .eq("id", merchant_id)
        .single();

      if (merchantError || !merchant) {
        return new Response(
          JSON.stringify({ error: "Merchant not found" }),
          { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const balance = parseFloat(merchant.wallet_balance);
      const newBalance = balance + parseFloat(amount);

      // Determine new status. If they were suspended due to lack of funds but their package hasn't expired:
      let newStatus = merchant.status;
      const isExpired = merchant.package_expiry_date ? new Date(merchant.package_expiry_date) < new Date() : false;

      if (merchant.status === "suspended" && newBalance > 0 && !isExpired && merchant.current_tier_id) {
        newStatus = "active";
      }

      // Update merchant
      const { error: updateError } = await supabaseAdmin
        .from("merchants")
        .update({
          wallet_balance: newBalance,
          status: newStatus,
          updated_at: new Date().toISOString(),
        })
        .eq("id", merchant_id);

      if (updateError) {
        return new Response(
          JSON.stringify({ error: "Failed to update merchant wallet: " + updateError.message }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Create transaction record
      await supabaseAdmin.from("wallet_transactions").insert({
        merchant_id,
        amount: parseFloat(amount),
        type: "credit",
        description: notes || "Wallet top up",
      });

      return new Response(
        JSON.stringify({
          success: true,
          message: `Successfully topped up wallet by ${amount} EGP.`,
          wallet_balance: newBalance,
          merchant_status: newStatus,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // =========================================================================
    // ENDPOINT: POST /cancel-order
    // =========================================================================
    if (path.endsWith("/cancel-order") && req.method === "POST") {
      const { order_id, cancellation_reason } = await req.json();

      if (!order_id) {
        return new Response(
          JSON.stringify({ error: "Missing order_id" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Fetch order details
      const { data: order, error: orderError } = await supabaseAdmin
        .from("orders")
        .select("*, stores(merchant_id)")
        .eq("id", order_id)
        .single();

      if (orderError || !order) {
        return new Response(
          JSON.stringify({ error: "Order not found" }),
          { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const orderMerchantId = order.stores?.merchant_id;

      // Verify caller is the merchant of this order, or an admin
      if (userRole !== "admin" && user.id !== orderMerchantId) {
        return new Response(
          JSON.stringify({ error: "Forbidden: You do not own this order." }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Strict cancellation logic
      if (order.status === "picked_up" || order.status === "in_transit" || order.status === "delivered") {
        return new Response(
          JSON.stringify({ error: "Action Unauthorized: Order is already with the driver." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      if (order.status !== "pending" && order.status !== "confirmed") {
        return new Response(
          JSON.stringify({ error: "Action Unauthorized: Merchant can only cancel orders in pending or accepted status." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Perform cancellation. Let the trigger also validate this.
      const { error: cancelError } = await supabaseClient
        .from("orders")
        .update({
          status: "cancelled",
          cancellation_reason: cancellation_reason || "Cancelled by Merchant",
          cancelled_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq("id", order_id);

      if (cancelError) {
        return new Response(
          JSON.stringify({ error: cancelError.message }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({
          success: true,
          message: "Order successfully cancelled.",
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // =========================================================================
    // ENDPOINT: POST /cron-check
    // =========================================================================
    if (path.endsWith("/cron-check") && req.method === "POST") {
      // Run the database checking function
      const { error: cronError } = await supabaseAdmin.rpc("check_and_suspend_expired_merchants");

      if (cronError) {
        return new Response(
          JSON.stringify({ error: "Failed to execute suspension cron logic: " + cronError.message }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({
          success: true,
          message: "Merchant subscription expired packages and balances checked and processed successfully.",
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Unmatched path
    return new Response(
      JSON.stringify({ error: "Endpoint not found" }),
      { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    const errorMessage = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({ error: errorMessage }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
