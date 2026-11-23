-- Kata kunci alasan per grammar (untuk soal "Kenapa?" di Quiz)
alter table public.grammars add column if not exists kunci text;
alter table public.grammars drop constraint if exists grammars_kunci_check;
alter table public.grammars add constraint grammars_kunci_check check (kunci is null or length(kunci) <= 300);
