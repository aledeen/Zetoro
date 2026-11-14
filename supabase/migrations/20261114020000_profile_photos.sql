-- Foto profil: kolom foto, guru bisa ubah nama, bucket privat 'avatars'
alter table public.profiles add column if not exists foto text check (foto is null or length(foto) <= 200);

create policy profiles_upd on public.profiles for update to authenticated
  using (id = (select auth.uid()) or (select public.is_teacher()))
  with check (id = (select auth.uid()) or (select public.is_teacher()));
revoke update on public.profiles from authenticated;
grant update (foto, nama) on public.profiles to authenticated;

create or replace function public.profiles_guard() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  if new.nama is distinct from old.nama and not public.is_teacher() then
    raise exception 'Hanya guru yang bisa mengubah nama';
  end if;
  if new.foto is not null and new.foto not like (new.id::text || '/%') then
    raise exception 'invalid photo path';
  end if;
  return new;
end $$;
create trigger profiles_guard before update on public.profiles for each row execute function public.profiles_guard();

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', false, 1048576, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

create policy avatars_read on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and ((storage.foldername(name))[1] = (select auth.uid())::text or (select public.is_teacher())));
create policy avatars_ins on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and ((storage.foldername(name))[1] = (select auth.uid())::text or (select public.is_teacher())));
create policy avatars_upd on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and ((storage.foldername(name))[1] = (select auth.uid())::text or (select public.is_teacher())))
  with check (bucket_id = 'avatars' and ((storage.foldername(name))[1] = (select auth.uid())::text or (select public.is_teacher())));
create policy avatars_del on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and ((storage.foldername(name))[1] = (select auth.uid())::text or (select public.is_teacher())));
