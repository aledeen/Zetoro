# Zetoro

Web belajar vocabulary bahasa Inggris yang mobile-friendly: murid belajar lewat flashcard dan quiz, guru menilai dan membuka paket 20 kata per murid.

## Struktur

- `index.html`: seluruh aplikasi web (HTML + CSS + JS, tanpa build step)
- `supabase/migrations/`: skema database, RLS, dan fungsi
- `supabase/functions/zetoro-admin/`: edge function untuk setup guru, tambah murid, reset PIN, dan hapus murid
- `netlify.toml`: konfigurasi deploy Netlify

## Deploy

1. Hubungkan repo ini ke Netlify (Add new site → Import from GitHub). Tidak perlu build command; publish directory `.`.
2. Buka `https://<situs-kamu>/#guru` untuk membuat akun guru (hanya sekali).
3. Di Supabase Dashboard → Authentication → Sign In / Providers, matikan "Allow new users to sign up".

## Login

- Murid: username + PIN (dibuat oleh guru di menu Murid)
- Guru: email + password, lewat link yang diakhiri `#guru`

## Backend

Supabase project `Zetoro` (ap-northeast-1, organisasi Zetoro). Kunci yang ada di `index.html` adalah publishable key, aman untuk publik; keamanan data dijaga oleh Row Level Security.
