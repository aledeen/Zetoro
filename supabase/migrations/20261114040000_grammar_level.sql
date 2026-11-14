-- Level grammar per murid (diatur guru) + penanda notifikasi naik level
alter table public.profiles add column if not exists glevel smallint not null default 1 check (glevel between 1 and 3);
alter table public.profiles add column if not exists glevel_seen smallint not null default 1 check (glevel_seen between 1 and 3);
grant update (glevel, glevel_seen) on public.profiles to authenticated;
create or replace function public.profiles_guard() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  if new.nama is distinct from old.nama and not public.is_teacher() then
    raise exception 'Hanya guru yang bisa mengubah nama';
  end if;
  if new.glevel is distinct from old.glevel and not public.is_teacher() then
    raise exception 'Hanya guru yang bisa mengubah level grammar';
  end if;
  if new.foto is not null and new.foto not like (new.id::text || '/%') then
    raise exception 'invalid photo path';
  end if;
  return new;
end $$;
