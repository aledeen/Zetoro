-- Kata hari ini untuk halaman login (boleh dibaca tanpa login, hanya 1 kata)
create or replace function public.word_of_day()
returns table(kata text, arti text, contoh text, contoh_arti text)
language sql stable security definer set search_path = public as $$
  select w.kata, w.arti, w.contoh, w.contoh_arti
  from public.words w
  order by w.id
  offset (((now() at time zone 'Asia/Jakarta')::date - date '2026-01-01')
          % greatest((select count(*) from public.words), 1))
  limit 1;
$$;
revoke all on function public.word_of_day() from public;
grant execute on function public.word_of_day() to anon, authenticated;
