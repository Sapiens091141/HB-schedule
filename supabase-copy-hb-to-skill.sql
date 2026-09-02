-- ============================================================
-- คัดลอกรายชื่อนักเรียน HB → คอร์ส Skill (กลุ่มเดียวกัน)
-- + ผูกผู้ปกครองให้เห็นตาราง Skill ของลูกด้วย
--
-- รันใน Supabase SQL Editor · ต้องรัน supabase-course-migration.sql มาก่อน
-- รันซ้ำได้ทั้งไฟล์ ไม่สร้างซ้ำ ไม่ผูกซ้ำ
--
-- คัดลอกเฉพาะ "รายชื่อ" (ชื่อ/ชื่อเล่น/ชั้น) ไม่คัดลอกตารางเรียน
-- เพราะคาบของ Skill คนละชุดกับ HB (S15 เสาร์-อาทิตย์) — ตารางกรอกในเว็บเอา
--
-- นักเรียน 1 คนจะมี 2 แถวใน students คนละ id — ตาราง/การลา/บันทึกการเรียน
-- ของสองคอร์สจึงแยกกันสะอาด ไม่ปนกัน
-- ============================================================


-- ---------- ขั้น 0: ดูก่อนว่าจะเกิดอะไรขึ้น (ไม่แก้ข้อมูล) ----------
-- ไฮไลต์เฉพาะคำสั่งนี้แล้วกด Run ถ้าอยากเช็คก่อน
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
-- paid ตั้งเป็น false เพราะเป็นค่าเรียนคนละคอร์สกัน
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


-- ---------- ขั้น 2: ผูกผู้ปกครองให้เห็นคอร์ส Skill ด้วย ----------
-- allowed_users.student_ids เดิมชี้ไปที่ "แถว HB" เท่านั้น
-- ตรงนี้เติม id ของ "แถว Skill" ของลูกคนเดียวกันเข้าไปในอาร์เรย์
--
--   distinct        กัน id ซ้ำ กรณี HB มีชื่อ+ชื่อเล่นซ้ำกัน
--   <> all(...)     ข้ามคนที่ผูกไว้แล้ว → รันซ้ำได้ ไม่บวมขึ้นเรื่อยๆ
--   u.student_ids   ฝั่งขวาเป็นค่าเดิมก่อน update จึงเป็น "ของเดิม + ของใหม่"
update allowed_users u
set student_ids = u.student_ids || array(
      select distinct sk.id
        from students hb
        join students sk
          on sk.course = 'SKILL'
         and sk.name = hb.name
         and sk.nick = hb.nick
       where hb.course = 'HB'
         and hb.id = any(u.student_ids)
         and sk.id <> all(u.student_ids)
    )
where u.role = 'viewer'
  and coalesce(array_length(u.student_ids, 1), 0) > 0;


-- ---------- ขั้น 3: ตรวจผล ----------
select
  (select count(*) from students where course='HB')    as นักเรียน_hb,
  (select count(*) from students where course='SKILL') as นักเรียน_skill,
  (select count(*) from allowed_users u where u.role='viewer'
     and exists (select 1 from students s
                 where s.id = any(u.student_ids) and s.course='SKILL')) as ผู้ปกครองที่เห็น_skill;


-- ============================================================
-- ย้อนกลับ (ถ้าคัดลอกผิด) — ถอนการผูกก่อน แล้วค่อยลบนักเรียน
-- ระวัง: ถ้ากรอกตาราง/บันทึกการเรียนของ Skill ไปแล้ว จะหายไปด้วย
-- ============================================================
-- update allowed_users u
-- set student_ids = array(select x from unnest(u.student_ids) x
--                          where x not in (select id from students where course='SKILL'))
-- where u.role='viewer' and coalesce(array_length(u.student_ids,1),0) > 0;
--
-- delete from students where course = 'SKILL';
