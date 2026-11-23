-- Nilai quiz sekarang skala 0–100 (quiz 15 soal). Nilai lama (skala 10) dikali 10 sekali saja.
do $$ begin
  if (select coalesce(max(greatest(best, last)), 0) from public.quiz_results) <= 10 then
    update public.quiz_results set last = last * 10, best = best * 10;
  end if;
end $$;
create or replace function public.submit_quiz(p_bab bigint, p_paket text, p_score int)
returns public.quiz_results language plpgsql security definer set search_path = public as $$
declare r public.quiz_results;
begin
  if (select auth.uid()) is null then raise exception 'not signed in'; end if;
  if not exists(select 1 from public.profiles where id = (select auth.uid()) and role = 'student') then raise exception 'students only'; end if;
  if p_score < 0 or p_score > 100 then raise exception 'bad score'; end if;
  if not exists(select 1 from public.unlocks where student_id = (select auth.uid()) and bab_id = p_bab) then raise exception 'bab locked'; end if;
  insert into public.quiz_results(student_id, bab_id, paket, last, best, tries, updated_at)
  values ((select auth.uid()), p_bab, p_paket, p_score, p_score, 1, now())
  on conflict (student_id, bab_id, paket) do update
    set last = excluded.last, best = greatest(quiz_results.best, excluded.last), tries = quiz_results.tries + 1, updated_at = now()
  returning * into r;
  return r;
end $$;
