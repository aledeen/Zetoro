-- "Terakhir aktif" murid: diperbarui lewat fungsi (murid tidak bisa set waktu sembarangan)
alter table public.profiles add column if not exists last_seen timestamptz;

create or replace function public.touch_seen() returns void
language sql security definer set search_path to 'public' as $$
  update public.profiles set last_seen = now() where id = auth.uid();
$$;
revoke all on function public.touch_seen() from public, anon;
grant execute on function public.touch_seen() to authenticated;
