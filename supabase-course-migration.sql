-- ============================================================
-- HB Schedule — เพิ่มมิติ "คอร์ส" (HB / Skill)
-- รันครั้งเดียวใน Supabase SQL Editor
--
-- แนวคิด: คอร์สอยู่ที่ตาราง students ตารางเดียว
-- ตารางที่เหลือ (schedules / leave_requests / lesson_logs) ผูกกับ student_id อยู่แล้ว
-- จึงแยกคอร์สตามเจ้าของแถวไปเองโดยไม่ต้องแก้ schema หรือ RLS ของตารางเหล่านั้น
--
-- นักเรียนที่เรียนทั้ง 2 คอร์ส = 2 แถว คนละ id
-- (ตาราง/การลา/บันทึกการเรียน ของแต่ละคอร์สจึงแยกกันสะอาด
--  ส่วนผู้ปกครองผูกได้ทั้ง 2 id เพราะ allowed_users.student_ids เป็น array อยู่แล้ว)
-- ============================================================

alter table students add column if not exists course text not null default 'HB';

-- ข้อมูลเดิมทั้งหมดคือคอร์ส HB (default จัดการให้แล้ว แต่เขียนซ้ำกันพลาด)
update students set course='HB' where course is null or course='';

create index if not exists students_course_idx on students(course);

-- ตรวจ: ควรได้ HB = จำนวนนักเรียนเดิมทั้งหมด
-- select course, count(*) from students group by course order by course;
