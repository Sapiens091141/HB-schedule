-- ============================================================
-- HB-schedule : ฟีเจอร์ "บันทึกการเรียน" (lesson log) — v2
-- รันใน Supabase → SQL Editor → New query → Run  (รันซ้ำได้ปลอดภัย)
--
-- v2 เพิ่มจาก v1: เวลาเข้า-เลิกเรียน, ชีทหลายแผ่นต่อคาบ (JSONB), ความเห็นผู้สอน
--        และ "ตัดคอลัมน์ content ทิ้ง" — ใช้ชื่อชีทแทนเนื้อหาที่เรียน
--   ถ้าเคยรัน v1 ไปแล้ว สคริปต์นี้จะอัปเกรดให้เอง (ย้าย content → ชีทแผ่นแรก)
--
-- ระดับข้อมูล: รายคาบ → 1 แถว = (นักเรียน, วันที่, ช่วงเวลา)
-- โมเดลสิทธิ์: admin เขียน/แก้/ลบได้  ·  viewer อ่านได้เฉพาะนักเรียนใน student_ids
-- ============================================================

-- 1) ตาราง (กรณีติดตั้งใหม่) ----------------------------------------------
create table if not exists public.lesson_logs (
  id           bigint generated always as identity primary key,
  student_id   bigint not null references public.students(id) on delete cascade,
  iso_date     date   not null,
  slot         text   not null,                 -- M10 | M13 | M15 | M17
  start_time   time,                            -- เวลาเข้าเรียนจริง
  end_time     time,                            -- เวลาเลิกเรียนจริง
  sheets       jsonb  not null default '[]'::jsonb,
  --   [{ "name":"ตรีโกณ เล่ม 3", "video_done":true, "pages_done":12, "pages_total":20 }, ...]
  homework     text,                            -- การบ้าน
  teacher_note text,                            -- ความเห็นจากผู้สอน
  created_by   text,
  created_at   timestamptz default now(),
  updated_by   text,
  updated_at   timestamptz default now(),
  constraint lesson_logs_uniq unique (student_id, iso_date, slot),
  constraint lesson_logs_slot_valid check (slot in ('M10','M13','M15','M17'))
);

-- 2) อัปเกรดจาก v1 (เพิ่มคอลัมน์ที่ยังไม่มี) --------------------------------
alter table public.lesson_logs add column if not exists start_time   time;
alter table public.lesson_logs add column if not exists end_time     time;
alter table public.lesson_logs add column if not exists sheets       jsonb not null default '[]'::jsonb;
alter table public.lesson_logs add column if not exists homework     text;
alter table public.lesson_logs add column if not exists teacher_note text;
alter table public.lesson_logs add column if not exists updated_by   text;

-- 3) ตัดคอลัมน์ content ทิ้ง — ย้ายข้อมูลเดิมไปเป็น "ชีทแผ่นแรก" ก่อนลบ ---------
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='lesson_logs' and column_name='content') then
    update public.lesson_logs
       set sheets = jsonb_build_array(
             jsonb_build_object('name', content, 'video_done', false,
                                'pages_done', null, 'pages_total', null))
     where sheets = '[]'::jsonb
       and content is not null and btrim(content) <> '';
    alter table public.lesson_logs drop constraint if exists lesson_logs_content_notblank;
    alter table public.lesson_logs drop column content;
  end if;
end $$;

-- sheets ต้องเป็น array เสมอ (กันข้อมูลเพี้ยนจากฝั่ง client)
alter table public.lesson_logs drop constraint if exists lesson_logs_sheets_isarray;
alter table public.lesson_logs add  constraint lesson_logs_sheets_isarray
  check (jsonb_typeof(sheets) = 'array');

-- index: ดึง "ล่าสุดของนักเรียนคนหนึ่ง" และ feed รายวัน ให้เร็ว
create index if not exists lesson_logs_student_date_idx
  on public.lesson_logs (student_id, iso_date desc, slot desc);
create index if not exists lesson_logs_date_idx
  on public.lesson_logs (iso_date desc);

-- 4) Row Level Security --------------------------------------------------
alter table public.lesson_logs enable row level security;

drop policy if exists ll_read   on public.lesson_logs;
drop policy if exists ll_insert on public.lesson_logs;
drop policy if exists ll_update on public.lesson_logs;
drop policy if exists ll_delete on public.lesson_logs;

-- อ่าน: admin เห็นหมด / viewer เห็นเฉพาะของนักเรียนที่ตัวเองผูก
--   (เงื่อนไขเดียวกับ lr_read ใน supabase-leave-migration.sql)
create policy ll_read on public.lesson_logs
  for select to authenticated
  using (
    exists (select 1 from public.allowed_users u
            where u.email = auth.email()
              and (u.role = 'admin' or lesson_logs.student_id = any(u.student_ids)))
  );

-- เขียน: admin เท่านั้น (ไม่มีสาขา student_ids — viewer เป็นผู้อ่านอย่างเดียว)
create policy ll_insert on public.lesson_logs
  for insert to authenticated
  with check (
    exists (select 1 from public.allowed_users u
            where u.email = auth.email() and u.role = 'admin')
  );

-- แก้: admin เท่านั้น
create policy ll_update on public.lesson_logs
  for update to authenticated
  using (
    exists (select 1 from public.allowed_users u
            where u.email = auth.email() and u.role = 'admin')
  )
  with check (
    exists (select 1 from public.allowed_users u
            where u.email = auth.email() and u.role = 'admin')
  );

-- ลบ: admin เท่านั้น
create policy ll_delete on public.lesson_logs
  for delete to authenticated
  using (
    exists (select 1 from public.allowed_users u
            where u.email = auth.email() and u.role = 'admin')
  );

-- ============================================================
-- ตรวจสอบหลังรัน:
--   select * from pg_policies where tablename = 'lesson_logs';   -- ต้องได้ 4 แถว
--   select column_name from information_schema.columns
--    where table_name='lesson_logs' order by ordinal_position;   -- ต้องไม่มี content
-- ============================================================
