-- ============================================================
-- HB-schedule : บังคับตั้ง "ชื่อผู้ใช้" ตอนลงทะเบียน
-- เพิ่มคอลัมน์ display_name ให้ allowed_users
-- รันใน Supabase → SQL Editor → New query → Run  (รันซ้ำได้ปลอดภัย)
-- ============================================================

alter table public.allowed_users add column if not exists display_name text;

-- หมายเหตุ: ใช้ RLS insert เดิมของ allowed_users (ตอนลงทะเบียนแอปจะ insert
--   {email, role:'pending', display_name}) — ไม่ต้องเพิ่ม policy ใหม่
-- ============================================================
