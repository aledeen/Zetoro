-- Rumus grammar boleh lebih panjang (sampai 600 karakter, boleh beberapa baris)
alter table public.grammars drop constraint if exists grammars_rumus_check;
alter table public.grammars add constraint grammars_rumus_check check (length(rumus) <= 600);
