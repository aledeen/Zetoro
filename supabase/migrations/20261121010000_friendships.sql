-- Pertemanan antar murid: cari lewat username persis, minta pertemanan, terima/tolak.
-- Murid tetap tidak bisa membaca profil/progres murid lain secara langsung;
-- semuanya lewat fungsi di bawah, dan data lengkap hanya untuk yang sudah berteman.

create table if not exists public.friendships (
  id bigint generated always as identity primary key,
  requester uuid not null references public.profiles(id) on delete cascade,
  addressee uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (requester <> addressee)
);
create unique index if not exists friendships_pair on public.friendships (least(requester, addressee), greatest(requester, addressee));
create index if not exists friendships_addressee on public.friendships (addressee);
alter table public.friendships enable row level security;
create policy friendships_read on public.friendships for select to authenticated
  using (requester = (select auth.uid()) or addressee = (select auth.uid()) or (select public.is_teacher()));
revoke insert, update, delete on public.friendships from anon, authenticated;

create or replace function public.are_friends(a uuid, b text) returns boolean
language sql stable security definer set search_path to 'public' as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester = a and f.addressee::text = b) or (f.addressee = a and f.requester::text = b))
  );
$$;

create or replace function public.find_student(p_username text)
returns table (id uuid, nama text, username text, rel text)
language sql stable security definer set search_path to 'public' as $$
  select p.id, p.nama, p.username,
    coalesce((
      select case when f.status = 'accepted' then 'friend'
                  when f.requester = auth.uid() then 'sent' else 'received' end
      from public.friendships f
      where (f.requester = auth.uid() and f.addressee = p.id) or (f.requester = p.id and f.addressee = auth.uid())
      limit 1), 'none')
  from public.profiles p
  where p.role = 'student'
    and lower(p.username) = lower(trim(p_username))
    and p.id <> auth.uid()
    and exists (select 1 from public.profiles me where me.id = auth.uid() and me.role = 'student');
$$;

create or replace function public.friend_request(p_to uuid) returns text
language plpgsql security definer set search_path to 'public' as $$
declare me uuid := auth.uid(); f public.friendships;
begin
  if me is null or me = p_to then raise exception 'Permintaan tidak valid'; end if;
  if not exists (select 1 from public.profiles where id = me and role = 'student')
     or not exists (select 1 from public.profiles where id = p_to and role = 'student') then
    raise exception 'Pertemanan hanya untuk murid';
  end if;
  select * into f from public.friendships
   where (requester = me and addressee = p_to) or (requester = p_to and addressee = me);
  if not found then
    insert into public.friendships (requester, addressee) values (me, p_to);
    return 'sent';
  end if;
  if f.status = 'accepted' then return 'friend'; end if;
  if f.addressee = me then
    update public.friendships set status = 'accepted', responded_at = now() where id = f.id;
    return 'friend';
  end if;
  return 'sent';
end $$;

create or replace function public.friend_respond(p_from uuid, p_accept boolean) returns text
language plpgsql security definer set search_path to 'public' as $$
declare me uuid := auth.uid();
begin
  if p_accept then
    update public.friendships set status = 'accepted', responded_at = now()
     where requester = p_from and addressee = me and status = 'pending';
    return 'friend';
  end if;
  delete from public.friendships where requester = p_from and addressee = me and status = 'pending';
  return 'none';
end $$;

create or replace function public.friend_remove(p_other uuid) returns text
language plpgsql security definer set search_path to 'public' as $$
declare me uuid := auth.uid();
begin
  delete from public.friendships
   where (requester = me and addressee = p_other) or (requester = p_other and addressee = me);
  return 'none';
end $$;

create or replace function public.my_friends()
returns table (id uuid, nama text, username text, rel text, foto text, bio text, glevel smallint, hafal int, aktif jsonb, best jsonb)
language sql stable security definer set search_path to 'public' as $$
  with r as (
    select case when f.requester = auth.uid() then f.addressee else f.requester end as oid,
           case when f.status = 'accepted' then 'friend'
                when f.requester = auth.uid() then 'sent' else 'received' end as rel
    from public.friendships f
    where f.requester = auth.uid() or f.addressee = auth.uid()
  )
  select p.id, p.nama, p.username, r.rel,
    case when r.rel = 'friend' then p.foto end,
    case when r.rel = 'friend' then p.bio end,
    case when r.rel = 'friend' then p.glevel end,
    case when r.rel = 'friend' then (select count(*)::int from public.statuses s where s.student_id = p.id and s.status = 'hafal') end,
    case when r.rel = 'friend' then (
      select coalesce(jsonb_agg(jsonb_build_object('bab', b.nama, 'paket', u.paket) order by b.id), '[]'::jsonb)
      from public.unlocks u join public.babs b on b.id = u.bab_id where u.student_id = p.id) end,
    case when r.rel = 'friend' then (
      select coalesce(jsonb_agg(jsonb_build_object('bab', b.nama, 'paket', q.paket, 'best', q.best) order by b.id, q.paket), '[]'::jsonb)
      from public.quiz_results q join public.babs b on b.id = q.bab_id where q.student_id = p.id) end
  from r join public.profiles p on p.id = r.oid
  order by r.rel, p.nama;
$$;

revoke all on function public.are_friends(uuid, text) from public, anon;
revoke all on function public.find_student(text) from public, anon;
revoke all on function public.friend_request(uuid) from public, anon;
revoke all on function public.friend_respond(uuid, boolean) from public, anon;
revoke all on function public.friend_remove(uuid) from public, anon;
revoke all on function public.my_friends() from public, anon;
grant execute on function public.are_friends(uuid, text) to authenticated;
grant execute on function public.find_student(text) to authenticated;
grant execute on function public.friend_request(uuid) to authenticated;
grant execute on function public.friend_respond(uuid, boolean) to authenticated;
grant execute on function public.friend_remove(uuid) to authenticated;
grant execute on function public.my_friends() to authenticated;

-- Foto profil teman boleh dibuka
create policy avatars_read_friends on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and public.are_friends((select auth.uid()), (storage.foldername(name))[1]));
