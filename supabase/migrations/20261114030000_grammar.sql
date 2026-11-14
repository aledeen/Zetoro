-- Grammar: daftar materi grammar + tanda grammar di contoh kalimat vocab
create table if not exists public.grammars (
  id bigint generated always as identity primary key,
  key text not null unique check (key ~ '^[a-z0-9-]{2,40}$'),
  judul text not null check (length(judul) between 1 and 80),
  level smallint not null default 1 check (level between 1 and 3),
  grup text not null default 'other' check (grup in ('tense','pronoun','tobe','prep','other')),
  rumus text not null default '' check (length(rumus) <= 200),
  penjelasan text not null default '' check (length(penjelasan) <= 400),
  detail text not null default '' check (length(detail) <= 3000),
  contoh text not null default '' check (length(contoh) <= 1000),
  created_at timestamptz not null default now()
);
alter table public.grammars enable row level security;
create policy grammars_read on public.grammars for select to authenticated using (true);
create policy grammars_ins on public.grammars for insert to authenticated with check ((select public.is_teacher()));
create policy grammars_upd on public.grammars for update to authenticated using ((select public.is_teacher())) with check ((select public.is_teacher()));
create policy grammars_del on public.grammars for delete to authenticated using ((select public.is_teacher()));
grant select, insert, update, delete on public.grammars to authenticated;

-- tanda: [{"t":"goes","g":"simple-present","d":["go","going","went"]}] maksimal 2
alter table public.words add column if not exists tanda jsonb
  check (tanda is null or (jsonb_typeof(tanda) = 'array' and jsonb_array_length(tanda) <= 2 and length(tanda::text) <= 1000));

insert into public.grammars (key, judul, level, grup, rumus, penjelasan, detail, contoh) values
('to-be','To be (am / is / are)',1,'tobe','I + am · He/She/It + is · You/We/They + are','"To be" artinya adalah/sedang/berada. Dipakai untuk menjelaskan keadaan, sifat, atau tempat.','I selalu memakai am. He, she, it, dan satu benda memakai is. You, we, they, dan benda jamak memakai are. Kalimat negatif: tambahkan not (I am not, she is not / isn''t). Kalimat tanya: pindahkan to be ke depan (Are you tired?).','I am a student.
She is happy.
They are at home.'),
('pronoun','Pronoun subjek (I, you, he, she…)',1,'pronoun','I · you · he · she · it · we · they','Kata ganti orang yang menjadi pelaku di awal kalimat.','I = saya, you = kamu/kalian, he = dia laki-laki, she = dia perempuan, it = benda/hewan, we = kami/kita, they = mereka. Pilihan pronoun menentukan bentuk kata kerja dan to be setelahnya.','He reads a book.
We play football.
It is my cat.'),
('simple-present','Simple Present',1,'tense','Subjek + kata kerja dasar (he/she/it + s/es)','Untuk kebiasaan, rutinitas, dan fakta yang selalu benar.','Dipakai dengan kata seperti every day, always, usually, often. Untuk he/she/it kata kerjanya ditambah -s atau -es. Negatif: do not / does not + kata kerja dasar. Tanya: Do/Does + subjek + kata kerja dasar?','I wake up at 5 a.m.
She goes to school every day.
Water boils at 100 degrees.'),
('verb-s-es','Kata kerja + s / es',1,'tense','he/she/it + verb-s · verb-es (go→goes, watch→watches)','Kalau subjeknya he, she, it, atau satu orang/benda, kata kerja di Simple Present ditambah -s atau -es.','Umumnya cukup + s (eat → eats). Tambah -es untuk akhiran o, s, sh, ch, x (go → goes, wash → washes). Konsonan + y menjadi -ies (study → studies). Have menjadi has.','He eats rice.
My mother cooks every morning.
She studies English.'),
('plural','Kata benda jamak (plural)',1,'other','benda + s / es (book → books)','Untuk benda lebih dari satu, kata bendanya ditambah -s atau -es.','Ada yang tidak beraturan: child → children, man → men, woman → women, foot → feet, tooth → teeth. Ada juga yang sama: fish, sheep.','I have two books.
The children are playing.
She brushes her teeth.'),
('article','Article a / an / the',1,'other','a + bunyi konsonan · an + bunyi vokal · the = yang tadi/yang itu','a dan an artinya "sebuah/seorang" untuk benda yang belum spesifik. the untuk benda yang sudah jelas yang mana.','a book, a university (bunyi "yu"). an apple, an hour (h tidak dibaca). the dipakai kalau benda sudah disebut atau hanya ada satu (the sun, the door).','I eat an apple.
She has a cat.
Close the door, please.'),
('possessive','Kata kepemilikan (my, your, his…)',1,'pronoun','my · your · his · her · its · our · their + benda','Menunjukkan milik siapa sebuah benda. Diletakkan sebelum kata benda.','my = milikku, your = milikmu, his = miliknya (laki-laki), her = miliknya (perempuan), its = milik benda/hewan, our = milik kami, their = milik mereka.','This is my bag.
Her house is big.
They wash their car.'),
('prep-place','Preposition tempat (in, on, at)',1,'prep','in = di dalam · on = di atas · at = di (titik tempat)','Kata depan untuk menunjukkan posisi atau tempat.','in untuk ruang atau wilayah (in the room, in Jakarta). on untuk permukaan (on the table, on the wall). at untuk titik atau tempat kegiatan (at home, at school, at the door).','The book is on the table.
I am at home.
She lives in Bandung.'),
('present-continuous','Present Continuous',2,'tense','am/is/are + verb-ing','Untuk kegiatan yang sedang terjadi sekarang.','Sering bersama now, right now, at the moment. Aturan -ing: hilangkan e di akhir (make → making), konsonan akhir digandakan pada kata pendek (run → running, swim → swimming).','I am reading a book.
She is cooking now.
They are playing outside.'),
('simple-past','Simple Past',2,'tense','Subjek + verb-2 (regular: +ed, irregular: berubah)','Untuk kejadian yang sudah selesai di masa lalu.','Regular: + ed (play → played, watch → watched). Irregular harus dihafal (go → went, eat → ate, see → saw, have → had). Negatif: did not + kata kerja dasar. Tanya: Did + subjek + kata kerja dasar?','I went to the market yesterday.
She cooked rice last night.
We watched a movie.'),
('future','Future (will / going to)',2,'tense','will + kata kerja dasar · am/is/are going to + kata kerja dasar','Untuk hal yang akan terjadi.','will untuk keputusan saat itu, janji, atau perkiraan (I will help you). going to untuk rencana yang sudah dibuat sebelumnya (I am going to visit my aunt tomorrow).','I will call you later.
She is going to study tonight.
It will rain soon.'),
('modal','Modal: can / must / should',2,'other','can / must / should + kata kerja dasar','Kata bantu untuk kemampuan (can), keharusan (must), dan saran (should).','Setelah modal, kata kerja selalu bentuk dasar tanpa -s: She can swim (bukan cans swims). Negatif: cannot / can''t, must not, should not.','I can swim.
You must wear a helmet.
You should drink water.'),
('prep-time','Preposition waktu (in, on, at)',2,'prep','at + jam · on + hari/tanggal · in + bulan/tahun/bagian hari','Kata depan untuk menunjukkan waktu.','at 7 o''clock, at night, at noon. on Monday, on 17 August, on my birthday. in July, in 2026, in the morning, in the evening.','I wake up at 5 a.m.
We go to the mosque on Friday.
She was born in 2010.'),
('comparison','Comparative & superlative',2,'other','adj-er than · the adj-est · more/most + adj panjang','Untuk membandingkan dua hal (lebih …) atau menyatakan paling.','Kata pendek: tall → taller → the tallest. Kata panjang: beautiful → more beautiful → the most beautiful. Tidak beraturan: good → better → the best, bad → worse → the worst.','My bag is bigger than yours.
She is the tallest in the class.
This book is more interesting.'),
('there-is','There is / there are',2,'tobe','there is + benda tunggal · there are + benda jamak','Artinya "ada", untuk menyatakan keberadaan sesuatu.','there is a/an + satu benda, there are + benda jamak. Tanya: Is there…? / Are there…? Negatif: there isn''t / there aren''t.','There is a cat in the kitchen.
There are three chairs.
Is there a mosque near here?'),
('present-perfect','Present Perfect',3,'tense','have/has + verb-3','Untuk pengalaman, atau kejadian lampau yang hasilnya masih terasa sekarang.','Sering bersama already, yet, just, ever, never, since, for. I/you/we/they + have, he/she/it + has. Verb-3 contoh: eat → eaten, go → gone, see → seen, finish → finished.','I have finished my homework.
She has never been to Bali.
We have lived here for five years.'),
('past-continuous','Past Continuous',3,'tense','was/were + verb-ing','Untuk kegiatan yang sedang berlangsung di waktu tertentu di masa lalu.','Sering dipakai bersama when atau while: kegiatan panjang (past continuous) terpotong kejadian pendek (simple past).','I was sleeping when you called.
They were studying at 8 p.m.
She was cooking while I was reading.'),
('passive','Passive voice',3,'other','to be + verb-3 (+ by …)','Kalimat yang fokus pada benda yang dikenai pekerjaan, bukan pelakunya.','Aktif: My mother cooks the rice. Pasif: The rice is cooked by my mother. To be mengikuti waktu: is/are (sekarang), was/were (lampau), will be (akan).','The rice is cooked by my mother.
This mosque was built in 1990.
The letter will be sent tomorrow.'),
('conditional','Conditional (if…)',3,'other','If + simple present, will + kata kerja · If + simple past, would + kata kerja','Kalimat pengandaian: jika… maka….','Tipe 1 untuk hal yang mungkin terjadi: If it rains, I will stay home. Tipe 2 untuk khayalan atau hal yang tidak nyata sekarang: If I had wings, I would fly.','If it rains, I will stay home.
If you study, you will pass.
If I were rich, I would build a school.'),
('gerund-infinitive','Gerund & to-infinitive',3,'other','kata kerja + verb-ing · kata kerja + to + verb','Setelah kata kerja tertentu, kata kerja berikutnya memakai -ing atau to + kata kerja dasar.','Diikuti -ing: enjoy, finish, mind, avoid (I enjoy reading). Diikuti to: want, need, plan, decide, hope (I want to learn). Setelah preposition selalu -ing (good at swimming).','I enjoy reading books.
She wants to learn English.
He is good at swimming.')
on conflict (key) do nothing;
