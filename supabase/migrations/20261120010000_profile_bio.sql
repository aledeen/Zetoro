-- Bio singkat di profil (seperti IG), bisa diubah oleh pemilik akun sendiri
alter table public.profiles add column if not exists bio text not null default '' check (length(bio) <= 100);
grant update (bio) on public.profiles to authenticated;
