create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('teacher','student')),
  nama text not null,
  username text unique,
  created_at timestamptz not null default now()
);

create table public.babs (
  id bigint generated always as identity primary key,
  nama text not null check (length(nama) between 1 and 80),
  created_at timestamptz not null default now()
);

create table public.words (
  id bigint generated always as identity primary key,
  bab_id bigint not null references public.babs(id) on delete cascade,
  kata text not null check (length(kata) between 1 and 120),
  arti text not null check (length(arti) between 1 and 200),
  contoh text not null check (length(contoh) between 1 and 400),
  created_at timestamptz not null default now()
);
create index words_bab_idx on public.words(bab_id, id);

create table public.unlocks (
  student_id uuid not null references public.profiles(id) on delete cascade,
  bab_id bigint not null references public.babs(id) on delete cascade,
  paket int not null default 1 check (paket >= 1),
  primary key (student_id, bab_id)
);
create index unlocks_bab_idx on public.unlocks(bab_id);

create table public.statuses (
  student_id uuid not null references public.profiles(id) on delete cascade,
  word_id bigint not null references public.words(id) on delete cascade,
  status text not null check (status in ('baru','belum','hafal')),
  updated_at timestamptz not null default now(),
  primary key (student_id, word_id)
);
create index statuses_word_idx on public.statuses(word_id);

create table public.quiz_results (
  student_id uuid not null references public.profiles(id) on delete cascade,
  bab_id bigint not null references public.babs(id) on delete cascade,
  paket text not null,
  last int not null default 0,
  best int not null default 0,
  tries int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (student_id, bab_id, paket)
);
create index quiz_bab_idx on public.quiz_results(bab_id);

create or replace function public.is_teacher()
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles where id = (select auth.uid()) and role = 'teacher');
$$;
revoke execute on function public.is_teacher() from public, anon;
grant execute on function public.is_teacher() to authenticated;

alter table public.profiles enable row level security;
alter table public.babs enable row level security;
alter table public.words enable row level security;
alter table public.unlocks enable row level security;
alter table public.statuses enable row level security;
alter table public.quiz_results enable row level security;

create policy profiles_read on public.profiles for select to authenticated
  using (id = (select auth.uid()) or (select public.is_teacher()));

create policy babs_read on public.babs for select to authenticated using (true);
create policy babs_ins on public.babs for insert to authenticated with check ((select public.is_teacher()));
create policy babs_upd on public.babs for update to authenticated using ((select public.is_teacher())) with check ((select public.is_teacher()));
create policy babs_del on public.babs for delete to authenticated using ((select public.is_teacher()));

create policy words_read on public.words for select to authenticated using (true);
create policy words_ins on public.words for insert to authenticated with check ((select public.is_teacher()));
create policy words_upd on public.words for update to authenticated using ((select public.is_teacher())) with check ((select public.is_teacher()));
create policy words_del on public.words for delete to authenticated using ((select public.is_teacher()));

create policy unlocks_read on public.unlocks for select to authenticated
  using (student_id = (select auth.uid()) or (select public.is_teacher()));
create policy unlocks_ins on public.unlocks for insert to authenticated with check ((select public.is_teacher()));
create policy unlocks_upd on public.unlocks for update to authenticated using ((select public.is_teacher())) with check ((select public.is_teacher()));
create policy unlocks_del on public.unlocks for delete to authenticated using ((select public.is_teacher()));

create policy statuses_read on public.statuses for select to authenticated
  using (student_id = (select auth.uid()) or (select public.is_teacher()));
create policy statuses_ins on public.statuses for insert to authenticated with check ((select public.is_teacher()));
create policy statuses_upd on public.statuses for update to authenticated using ((select public.is_teacher())) with check ((select public.is_teacher()));
create policy statuses_del on public.statuses for delete to authenticated using ((select public.is_teacher()));

create policy quiz_read on public.quiz_results for select to authenticated
  using (student_id = (select auth.uid()) or (select public.is_teacher()));

create or replace function public.submit_quiz(p_bab bigint, p_paket text, p_score int)
returns public.quiz_results language plpgsql security definer set search_path = public as $$
declare r public.quiz_results;
begin
  if (select auth.uid()) is null then raise exception 'not signed in'; end if;
  if not exists(select 1 from public.profiles where id = (select auth.uid()) and role = 'student') then raise exception 'students only'; end if;
  if p_score < 0 or p_score > 10 then raise exception 'bad score'; end if;
  if not exists(select 1 from public.unlocks where student_id = (select auth.uid()) and bab_id = p_bab) then raise exception 'bab locked'; end if;
  insert into public.quiz_results(student_id, bab_id, paket, last, best, tries, updated_at)
  values ((select auth.uid()), p_bab, p_paket, p_score, p_score, 1, now())
  on conflict (student_id, bab_id, paket) do update
    set last = excluded.last, best = greatest(quiz_results.best, excluded.last), tries = quiz_results.tries + 1, updated_at = now()
  returning * into r;
  return r;
end $$;
revoke execute on function public.submit_quiz(bigint, text, int) from public, anon;
grant execute on function public.submit_quiz(bigint, text, int) to authenticated;

create or replace function public.teacher_exists()
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles where role = 'teacher');
$$;
grant execute on function public.teacher_exists() to anon, authenticated;
