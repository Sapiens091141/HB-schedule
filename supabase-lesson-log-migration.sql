-- ============================================================
-- HB-schedule : ฟีเจอร์ "บันทึกเนื้อหาที่เรียน" (lesson log) — v1
-- รันใน Supabase → SQL Editor → New query → Run  (รันซ้ำได้ปลอดภัย)
--
-- ระดับข้อมูล: รายคาบ → 1 แถว = (นักเรียน, วันที่, ช่วงเวลา)
--   ทำให้มีประวัติครบทุกคาบ และคำนวณ "ล่าสุดที่เรียน" ของแต่ละคนได้
--
-- โมเดลสิทธิ์: admin เขียน/แก้/ลบได้  ·  viewer อ่านได้เฉพาะนักเรียนใน student_ids
--   (ต่างจาก leave_requests ตรงที่ viewer "เขียนไม่ได้" — เป็นบันทึกของครู)
-- ============================================================

-- 1) ตารางบันทึกเนื้อหาที่เรียน -------------------------------------------
create table if not exists public.lesson_logs (
  id          bigint generated always as identity primary key,
  student_id  bigint not null references public.students(id) on delete cascade,
  iso_date    date   not null,
  slot        text   not null,                 -- M10 | M13 | M15 | M17
  content     text   not null,                 -- เนื้อหาที่เรียนคาบนี้
  homework    text,                            -- การบ้าน (ถ้ามี)
  created_by  text,
  created_at  timestamptz default now(),
  updated_by  text,
  updated_at  timestamptz default now(),
  constraint lesson_logs_uniq unique (student_id, iso_date, slot),
  constraint lesson_logs_content_notblank check (btrim(content) <> ''),
  constraint lesson_logs_slot_valid check (slot in ('M10','M13','M15','M17'))
);

-- เผื่อกรณีเคยรันเวอร์ชันก่อนหน้าที่ยังไม่มีคอลัมน์เหล่านี้
alter table public.lesson_logs add column if not exists homework   text;
alter table public.lesson_logs add column if not exists updated_by text;

-- index: ดึง "ล่าสุดของนักเรียนคนหนึ่ง" และ feed รายวัน ให้เร็ว
create index if not exists lesson_logs_student_date_idx
  on public.lesson_logs (student_id, iso_date desc, slot desc);
create index if not exists lesson_logs_date_idx
  on public.lesson_logs (iso_date desc);

-- 2) Row Level Security --------------------------------------------------
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
-- เสร็จ — ครูแตะไอคอน 📝 บนชิปนักเรียนในตารางเรียน เพื่อบันทึกเนื้อหา
--        ผู้ปกครองเห็นในหน้ามือถือ (กล่อง "ล่าสุดที่เรียน" + บรรทัดใต้คาบ)
-- ============================================================
