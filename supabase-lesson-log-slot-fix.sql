-- ============================================================
-- HB-schedule : ปลดล็อกรหัสคาบของ lesson_logs ให้รองรับทุกคอร์ส
-- รันใน Supabase → SQL Editor → New query → Run  (รันซ้ำได้ปลอดภัย)
--
-- อาการที่แก้: คอร์ส Skill (คาบ S15) กดบันทึกการเรียนแล้วเหมือนบันทึกผ่าน
--   แต่พอรีเฟรชบันทึกหายไป — เพราะ CHECK เดิมเขียนรายชื่อคาบของคอร์ส HB ไว้ตายตัว
--     constraint lesson_logs_slot_valid check (slot in ('M10','M13','M15','M17'))
--   Postgres จึงปฏิเสธแถวที่ slot='S15' ตั้งแต่ตอน insert
--   (ตาราง schedules / leave_requests ไม่มี CHECK นี้ ตารางเรียนกับการลาของ Skill จึงใช้ได้ปกติ)
--
-- แก้เป็น "ตรวจรูปแบบ" แทน "ตรวจรายชื่อ" — เพิ่มคอร์ส/คาบใหม่ในเว็บได้โดยไม่ต้องแก้ DB อีก
--   รูปแบบรหัสคาบ = ตัวอักษรใหญ่ 1-2 ตัว + ตัวเลข 1-2 หลัก  เช่น M10 M13 M15 M17 S15
-- ============================================================

alter table public.lesson_logs drop constraint if exists lesson_logs_slot_valid;
alter table public.lesson_logs add  constraint lesson_logs_slot_valid
  check (slot ~ '^[A-Z]{1,2}[0-9]{1,2}$');

-- ============================================================
-- ตรวจสอบหลังรัน:
--   select conname, pg_get_constraintdef(oid) from pg_constraint
--    where conrelid = 'public.lesson_logs'::regclass and conname = 'lesson_logs_slot_valid';
--   -- ต้องได้ CHECK ((slot ~ '^[A-Z]{1,2}[0-9]{1,2}$'::text))
--
-- แล้วลองบันทึกการเรียนคาบ S15 ของคอร์ส Skill ซ้ำอีกครั้ง (ของเดิมที่หายไปต้องบันทึกใหม่)
-- ============================================================
