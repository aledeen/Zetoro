-- Arti (terjemahan Indonesia) dari contoh kalimat; opsional
alter table public.words
  add column if not exists contoh_arti text not null default ''
  check (length(contoh_arti) <= 400);
