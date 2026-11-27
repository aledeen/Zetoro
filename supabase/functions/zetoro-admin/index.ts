import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const STUDENT_DOMAIN = "murid.zetoro.app";
const hpToPw = (u: string, hp: string) => `zt:${u}:${hp}`;
const USER_RE = /^[a-z0-9_.]{3,20}$/;
const HP_RE = /^0\d{8,14}$/;
// nomor HP dinormalkan: hanya angka, +62/62 -> 0, 8xx -> 08xx
const normHp = (x: unknown) => {
  let d = String(x || "").replace(/\D/g, "");
  if (d.startsWith("62")) d = "0" + d.slice(2);
  else if (d.startsWith("8")) d = "0" + d;
  return d;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: "Invalid JSON" }, 400); }
  const action = String(body.action || "");

  try {
    if (action === "setup_teacher") {
      const { count } = await admin.from("profiles").select("id", { count: "exact", head: true }).eq("role", "teacher");
      if ((count ?? 0) > 0) return json({ error: "Akun guru sudah ada." }, 409);
      const nama = String(body.nama || "").trim().slice(0, 60);
      const email = String(body.email || "").trim().toLowerCase();
      const password = String(body.password || "");
      if (!nama || !/^\S+@\S+\.\S+$/.test(email) || password.length < 8)
        return json({ error: "Nama, email valid, dan password minimal 8 karakter wajib diisi." }, 400);
      const { data, error } = await admin.auth.admin.createUser({ email, password, email_confirm: true });
      if (error) return json({ error: error.message }, 400);
      const { error: e2 } = await admin.from("profiles").insert({ id: data.user.id, role: "teacher", nama });
      if (e2) { await admin.auth.admin.deleteUser(data.user.id); return json({ error: e2.message }, 400); }
      return json({ ok: true });
    }

    // everything else: teacher only
    const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
    const { data: u } = await admin.auth.getUser(token);
    if (!u?.user) return json({ error: "Silakan masuk sebagai guru." }, 401);
    const { data: me } = await admin.from("profiles").select("role").eq("id", u.user.id).maybeSingle();
    if (me?.role !== "teacher") return json({ error: "Khusus guru." }, 403);

    if (action === "create_student") {
      const nama = String(body.nama || "").trim().slice(0, 60);
      const username = String(body.username || "").trim().toLowerCase();
      const hp = normHp(body.no_hp);
      if (!nama) return json({ error: "Nama wajib diisi." }, 400);
      if (!USER_RE.test(username)) return json({ error: "Username 3–20 karakter: huruf kecil, angka, titik, atau garis bawah." }, 400);
      if (!HP_RE.test(hp)) return json({ error: "Nomor HP tidak valid. Contoh: 081234567890." }, 400);
      const { data: dup } = await admin.from("profiles").select("id").eq("username", username).maybeSingle();
      if (dup) return json({ error: "Username sudah dipakai. Coba yang lain." }, 409);
      const { data: dupHp } = await admin.from("profiles").select("nama").eq("no_hp", hp).maybeSingle();
      if (dupHp) return json({ error: `Nomor HP ini sudah dipakai ${dupHp.nama}. Satu nomor untuk satu murid.` }, 409);
      const { data, error } = await admin.auth.admin.createUser({
        email: `${username}@${STUDENT_DOMAIN}`, password: hpToPw(username, hp), email_confirm: true,
      });
      if (error) return json({ error: error.message }, 400);
      const { error: e2 } = await admin.from("profiles").insert({ id: data.user.id, role: "student", nama, username, no_hp: hp });
      if (e2) { await admin.auth.admin.deleteUser(data.user.id); return json({ error: e2.message }, 400); }
      const { data: first } = await admin.from("babs").select("id").order("id").limit(1).maybeSingle();
      if (first) await admin.from("unlocks").insert({ student_id: data.user.id, bab_id: first.id, paket: 1 });
      return json({ ok: true, id: data.user.id });
    }

    if (action === "reset_phone" || action === "reset_pin") {
      const id = String(body.student_id || "");
      const { data: p } = await admin.from("profiles").select("username,role").eq("id", id).maybeSingle();
      if (!p || p.role !== "student") return json({ error: "Murid tidak ditemukan." }, 404);
      // nomor HP baru = kata sandi masuk murid (satu nomor untuk satu murid)
      const hp = normHp(body.no_hp);
      if (!HP_RE.test(hp)) return json({ error: "Nomor HP tidak valid. Contoh: 081234567890." }, 400);
      const { data: dupHp } = await admin.from("profiles").select("id,nama").eq("no_hp", hp).neq("id", id).maybeSingle();
      if (dupHp) return json({ error: `Nomor HP ini sudah dipakai ${dupHp.nama}. Satu nomor untuk satu murid.` }, 409);
      const { error } = await admin.auth.admin.updateUserById(id, { password: hpToPw(p.username, hp) });
      if (error) return json({ error: error.message }, 400);
      const { error: e2 } = await admin.from("profiles").update({ no_hp: hp }).eq("id", id);
      if (e2) return json({ error: e2.message }, 400);
      return json({ ok: true, no_hp: hp });
    }

    if (action === "delete_student") {
      const id = String(body.student_id || "");
      const { data: p } = await admin.from("profiles").select("role").eq("id", id).maybeSingle();
      if (!p || p.role !== "student") return json({ error: "Murid tidak ditemukan." }, 404);
      const { error } = await admin.auth.admin.deleteUser(id);
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true });
    }

    return json({ error: "Unknown action" }, 400);
  } catch (e) {
    return json({ error: String((e as Error).message || e) }, 500);
  }
});
