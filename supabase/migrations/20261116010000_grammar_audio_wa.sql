-- Rekaman suara guru per materi grammar + pengaturan aplikasi (nomor WA guru)

alter table public.grammars add column if not exists audio_path text;
alter table public.grammars add column if not exists audio_dur int check (audio_dur is null or audio_dur between 0 and 600);

create table if not exists public.app_settings (
  key text primary key check (key ~ '^[a-z_]{1,40}$'),
  value text not null default '' check (length(value) <= 400),
  updated_at timestamptz not null default now()
);
alter table public.app_settings enable row level security;
create policy app_settings_read on public.app_settings for select to authenticated using (true);
create policy app_settings_ins on public.app_settings for insert to authenticated with check ((select public.is_teacher()));
create policy app_settings_upd on public.app_settings for update to authenticated using ((select public.is_teacher())) with check ((select public.is_teacher()));
create policy app_settings_del on public.app_settings for delete to authenticated using ((select public.is_teacher()));
grant select, insert, update, delete on public.app_settings to authenticated;

-- Bucket privat: semua user login boleh dengar (lewat signed URL), hanya guru yang boleh upload/hapus
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('grammar-audio', 'grammar-audio', false, 8388608,
        array['audio/webm','audio/ogg','audio/mp4','audio/mpeg','audio/aac','audio/x-m4a'])
on conflict (id) do nothing;

create policy grammar_audio_read on storage.objects for select to authenticated
  using (bucket_id = 'grammar-audio');
create policy grammar_audio_ins on storage.objects for insert to authenticated
  with check (bucket_id = 'grammar-audio' and (select public.is_teacher()));
create policy grammar_audio_upd on storage.objects for update to authenticated
  using (bucket_id = 'grammar-audio' and (select public.is_teacher()))
  with check (bucket_id = 'grammar-audio' and (select public.is_teacher()));
create policy grammar_audio_del on storage.objects for delete to authenticated
  using (bucket_id = 'grammar-audio' and (select public.is_teacher()));
