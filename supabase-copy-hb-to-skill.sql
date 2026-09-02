-- ============================================================
-- คัดลอกรายชื่อนักเรียน HB → คอร์ส Skill (กลุ่มเดียวกัน)
-- รันใน Supabase SQL Editor · ต้องรัน supabase-course-migration.sql มาก่อน
--
-- คัดลอกเฉพาะ "รายชื่อ" (ชื่อ/ชื่อเล่น/ชั้น) ไม่คัดลอกตารางเรียน
-- เพราะคาบของ Skill คนละชุดกับ HB (S15 เสาร์-อาทิตย์)
--
-- นักเรียน 1 คนจะมี 2 แถวใน students คนละ id — ตาราง/การลา/บันทึกการเรียน
-- ของสองคอร์สจึงแยกกันสะอาด ไม่ปนกัน
-- ============================================================


-- ---------- ขั้น 0: ดูก่อนว่าจะเกิดอะไรขึ้น (ไม่แก้ข้อมูล) ----------
select
  count(*) filter (where course='HB')                        as hb_ตอนนี้,
  count(*) filter (where course='SKILL')                     as skill_ตอนนี้,
  count(distinct (name,nick)) filter (where course='HB')     as hb_ชื่อไม่ซ้ำ
from students;
-- ถ้า hb_ตอนนี้ != hb_ชื่อไม่ซ้ำ แปลว่ามีคนชื่อ+ชื่อเล่นซ้ำกันเป๊ะ
-- ขั้น 1 จะสร้างให้แค่แถวเดียว → ดูรายชื่อที่ซ้ำด้วยคำสั่งนี้
--   select name, nick, count(*) from students where course='HB'
--   group by name, nick having count(*) > 1;


-- ---------- ขั้น 1: คัดลอกรายชื่อ ----------
-- paid ตั้งเป็น false เพราะเป็นค่าจ่ายเงินคนละคอร์สกัน
-- not exists = รันซ้ำได้ ไม่สร้างซ้ำ
insert into students (name, nick, grade, paid, course)
select hb.name, hb.nick, hb.grade, false, 'SKILL'
from students hb
where hb.course = 'HB'
  and not exists (
    select 1 from students sk
    where sk.course = 'SKILL'
      and sk.name = hb.name
      and sk.nick = hb.nick
  );


-- ---------- ขั้น 2: ตรวจผล ----------
select course, count(*) as จำนวน from students group by course order by course;


-- ============================================================
-- ขั้น 3 (ทางเลือก): ให้ผู้ปกครองเห็นตาราง Skill ของลูกด้วย
--
-- ตอนนี้ allowed_users.student_ids ชี้ไปที่ "แถว HB" เท่านั้น
-- ผู้ปกครองจึงยังไม่เห็นคอร์ส Skill จนกว่าจะผูก id ของแถว Skill เพิ่ม
--
-- รันบล็อกนี้ = ผูกให้อัตโนมัติทุกคนที่ผูก HB ไว้อยู่แล้ว (รันซ้ำได้)
-- ถ้าอยากเลือกผูกเป็นรายคน ข้ามบล็อกนี้ไป แล้วผูกเองในแท็บ "จัดการผู้ใช้"
-- (dropdown แสดงป้าย [HB] / [Skill] กำกับทุกชื่อ)
-- ============================================================

-- ดูก่อนว่าใครจะถูกผูกเพิ่มบ้าง (ไม่แก้ข้อมูล)
-- select u.email, u.display_name,
--        array(select sk.id from students hb
--                join students sk on sk.course='SKILL' and sk.name=hb.name and sk.nick=hb.nick
--               where hb.course='HB' and hb.id = any(u.student_ids)
--                 and sk.id <> all(u.student_ids)) as จะผูกเพิ่ม
-- from allowed_users u
-- where u.role='viewer' and coalesce(array_length(u.student_ids,1),0) > 0;

-- update allowed_users u
-- set student_ids = u.student_ids || array(
--       select sk.id from students hb
--         join students sk on sk.course='SKILL' and sk.name=hb.name and sk.nick=hb.nick
--        where hb.course='HB' and hb.id = any(u.student_ids)
--          and sk.id <> all(u.student_ids)
--     )
-- where u.role='viewer' and coalesce(array_length(u.student_ids,1),0) > 0;


-- ============================================================
-- ย้อนกลับ (ถ้าคัดลอกผิด) — ลบเฉพาะนักเรียน Skill ที่ยังไม่มีข้อมูลผูกอยู่
-- ระวัง: ถ้ากรอกตาราง/บันทึกการเรียนของ Skill ไปแล้ว จะหายไปด้วย
-- ============================================================
-- delete from students where course = 'SKILL';
