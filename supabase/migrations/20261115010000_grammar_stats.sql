-- Rekap jawaban grammar per murid (diisi lewat RPC record_grammar)
create table if not exists public.grammar_stats (
  student_id uuid not null references public.profiles(id) on delete cascade,
  grammar_key text not null check (length(grammar_key) between 1 and 60),
  benar int not null default 0 check (benar >= 0),
  total int not null default 0 check (total >= 0),
  updated_at timestamptz not null default now(),
  primary key (student_id, grammar_key)
);
alter table public.grammar_stats enable row level security;
create policy grammar_stats_read on public.grammar_stats for select to authenticated
  using (student_id = (select auth.uid()) or (select public.is_teacher()));
create policy grammar_stats_del on public.grammar_stats for delete to authenticated using ((select public.is_teacher()));
grant select, delete on public.grammar_stats to authenticated;

create or replace function public.record_grammar(p_items jsonb) returns void
language plpgsql security definer set search_path to 'public' as $$
declare it jsonb; uid uuid := auth.uid();
begin
  if uid is null or not exists (select 1 from profiles where id = uid and role = 'student') then
    raise exception 'students only';
  end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) > 20 then
    raise exception 'invalid items';
  end if;
  for it in select * from jsonb_array_elements(p_items) loop
    if not exists (select 1 from grammars where key = it->>'k') then continue; end if;
    insert into grammar_stats (student_id, grammar_key, benar, total)
      values (uid, it->>'k', case when (it->>'ok')::boolean then 1 else 0 end, 1)
    on conflict (student_id, grammar_key) do update
      set benar = grammar_stats.benar + excluded.benar, total = grammar_stats.total + 1, updated_at = now();
  end loop;
end $$;
revoke all on function public.record_grammar(jsonb) from public, anon;
grant execute on function public.record_grammar(jsonb) to authenticated;
