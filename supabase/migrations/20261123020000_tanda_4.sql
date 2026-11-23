-- Tanda grammar per kalimat: Pemula maks 2, Menengah 3, Lanjut 4 (dicek di aplikasi); database izinkan sampai 4
do $$ declare c text;
begin
  for c in select conname from pg_constraint
           where conrelid = 'public.words'::regclass and contype = 'c' and pg_get_constraintdef(oid) ilike '%tanda%'
  loop execute format('alter table public.words drop constraint %I', c); end loop;
end $$;
alter table public.words add constraint words_tanda_check
  check (tanda is null or (jsonb_typeof(tanda) = 'array' and jsonb_array_length(tanda) <= 4 and length(tanda::text) <= 2000));
