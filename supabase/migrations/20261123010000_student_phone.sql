-- Nomor HP murid: dipakai sebagai PIN, satu nomor untuk satu murid
alter table public.profiles add column if not exists no_hp text;
alter table public.profiles drop constraint if exists profiles_no_hp_chk;
alter table public.profiles add constraint profiles_no_hp_chk check (no_hp is null or no_hp ~ '^0[0-9]{8,14}$');
create unique index if not exists profiles_no_hp_key on public.profiles (no_hp) where no_hp is not null;
