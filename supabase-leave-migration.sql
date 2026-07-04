-- ============================================================
-- HB-schedule : ฟีเจอร์ "ขอลา"  (เวอร์ชัน 2.1 — ใช้โมเดล student_ids ของจริง)
-- รันใน Supabase → SQL Editor → New query → Run  (รันซ้ำได้ปลอดภัย)
--
-- โมเดลสิทธิ์ของแอป: allowed_users(email, role, student_ids[])
--   role = 'admin' | 'viewer' | 'pending'
--   viewer ผูกกับนักเรียนผ่าน student_ids (array) → viewer คือคนกดลา
--
-- ลำดับสำคัญ: ต้อง drop policy เก่า "ก่อน" แล้วจึง drop คอลัมน์ student_id
-- (policy v1 อ้างคอลัมน์นั้นอยู่ ถ้าลบคอลัมน์ก่อนจะ error 2BP01)
-- ============================================================

-- 1) ตารางคำขอลา (create if not exists — ถ้ารัน v1 ไปแล้วจะมีอยู่) ----------
create table if not exists public.leave_requests (
  id           bigint generated always as identity primary key,
  student_id   bigint not null references public.students(id) on delete cascade,
  iso_date     date   not null,
  slot         text   not null,                  -- M10 | M13 | M15 | M17
  reason       text,
  status       text   not null default 'pending',-- pending | approved | rejected
  days_notice  int,
  requested_by text,
  created_at   timestamptz default now(),
  decided_by   text,
  decided_at   timestamptz,
  constraint leave_requests_uniq unique (student_id, iso_date, slot)
);

create index if not exists leave_requests_date_idx   on public.leave_requests (iso_date);
create index if not exists leave_requests_status_idx on public.leave_requests (status);

-- 2) ล้าง policy เก่า (v1) ก่อน — เพื่อปลด dependency ที่อ้าง student_id ------
drop policy if exists lr_read   on public.leave_requests;
drop policy if exists lr_insert on public.leave_requests;
drop policy if exists lr_update on public.leave_requests;
drop policy if exists lr_delete on public.leave_requests;

-- 3) ตอนนี้ลบคอลัมน์ student_id (เอกพจน์) ที่ v1 เพิ่มผิดได้แล้ว ---------------
alter table public.allowed_users drop column if exists student_id;

-- 4) Row Level Security --------------------------------------------------
alter table public.leave_requests enable row level security;

-- เงื่อนไขร่วม: ผู้ใช้ปัจจุบันเป็น admin หรือ นักเรียนแถวนี้อยู่ใน student_ids ของเขา
--   (อ่าน allowed_users เฉพาะแถวตัวเอง: u.email = auth.email())

-- อ่าน: admin เห็นหมด / viewer เห็นเฉพาะของนักเรียนที่ตัวเองผูก
create policy lr_read on public.leave_requests
  for select to authenticated
  using (
    exists (select 1 from public.allowed_users u
            where u.email = auth.email()
              and (u.role = 'admin' or leave_requests.student_id = any(u.student_ids)))
  );

-- เพิ่ม: admin เพิ่มให้ใครก็ได้ / viewer เพิ่มได้เฉพาะนักเรียนที่ผูก
create policy lr_insert on public.leave_requests
  for insert to authenticated
  with check (
    exists (select 1 from public.allowed_users u
            where u.email = auth.email()
              and (u.role = 'admin' or leave_requests.student_id = any(u.student_ids)))
  );

-- แก้: admin (อนุมัติ/ปฏิเสธ) / viewer แก้ของนักเรียนที่ผูก (re-request)
create policy lr_update on public.leave_requests
  for update to authenticated
  using (
    exists (select 1 from public.allowed_users u
            where u.email = auth.email()
              and (u.role = 'admin' or leave_requests.student_id = any(u.student_ids)))
  )
  with check (
    exists (select 1 from public.allowed_users u
            where u.email = auth.email()
              and (u.role = 'admin' or leave_requests.student_id = any(u.student_ids)))
  );

-- ลบ: admin ลบได้ทุกอัน / viewer ยกเลิก (ลบ) ของนักเรียนที่ผูก
create policy lr_delete on public.leave_requests
  for delete to authenticated
  using (
    exists (select 1 from public.allowed_users u
            where u.email = auth.email()
              and (u.role = 'admin' or leave_requests.student_id = any(u.student_ids)))
  );

-- ============================================================
-- เสร็จ — viewer กดลาจากหน้ามือถือ, admin อนุมัติในแท็บ "จัดการผู้ใช้"
-- ============================================================
