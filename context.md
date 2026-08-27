# HB Schedule — Project Context

ระบบจัดการ **ตารางเรียน HB** (สถาบันติว) — เว็บแอปไฟล์เดียว ภาษาไทย
อัปเดตล่าสุด: 2026-08-27

- **เว็บจริง:** https://sapiens091141.github.io/HB-schedule/
- **Repo:** `Sapiens091141/HB-schedule` (GitHub Pages, branch `main`, root)
- **Deploy:** `git push origin main` → Pages build อัตโนมัติ (มี `.nojekyll` ข้าม Jekyll)
- **gh CLI:** ล็อกอินเป็น `soonlearning09-lab` (เป็น *collaborator* ของ repo)

---

## 1. สถาปัตยกรรม

| ส่วน | รายละเอียด |
|---|---|
| Frontend | **ไฟล์เดียว `index.html`** (HTML+CSS+vanilla JS ล้วน, ไม่มี framework/build), ฟอนต์ Sarabun, เป็น PWA (`manifest.json` + ไอคอน) |
| Backend | **Supabase** (project ref `zpsarnenawaxmhkgjwwg`) ใช้ทั้ง Auth และ Postgres — SDK โหลดจาก CDN, anon key ฝังใน `index.html` (ปลอดภัยด้วย RLS) |
| Hosting | GitHub Pages (static) |

**ค่าคงที่ธุรกิจ:** วันเรียน = อา/พุธ/ศุกร์/เสาร์ (`CDOW=[0,3,5,6]`) · ช่วงเวลา 4 รอบ `M10` (10-12), `M13` (13-15), `M15` (15-17), `M17` (17-19) · แสดงปี พ.ศ. (ปี ค.ศ. +543)

---

## 2. สิทธิ์ผู้ใช้ (Roles)

`allowed_users.role` มี 3 แบบ:
- **`pending`** — สมัครใหม่ รอ admin อนุมัติ (login แล้วเจอหน้า "รอการอนุมัติ")
- **`viewer`** — ผู้ปกครอง/นักเรียน เห็น **หน้ามือถือ (viewer page)** เฉพาะตารางของนักเรียนที่ผูกไว้ (`student_ids`)
- **`admin`** — เข้าถึงทุกอย่าง: จัดการนักเรียน, Import CSV, อนุมัติผู้ใช้, ผูกนักเรียน↔อีเมล, อนุมัติการลา

**การผูกนักเรียน:** `allowed_users.student_ids` (array) → viewer 1 บัญชีผูกได้หลายนักเรียน (เช่นผู้ปกครองมีลูกหลายคน) · admin ผูก/ถอนในแท็บ "จัดการผู้ใช้"

---

## 3. Database schema (Supabase)

| ตาราง | คอลัมน์สำคัญ |
|---|---|
| `students` | `id, name, nick, grade, paid` |
| `schedules` | `student_id, iso_date (date), slots (text[])` — unique(student_id, iso_date) |
| `allowed_users` | `email, role, student_ids (int[]), display_name` |
| `leave_requests` | `id, student_id, iso_date, slot, reason, status (pending/approved/rejected), days_notice, requested_by, decided_by, decided_at` — unique(student_id, iso_date, slot) |
| `lesson_logs` | `id, student_id, iso_date, slot, start_time (time), end_time (time), sheets (jsonb), homework, teacher_note, created_by, created_at, updated_by, updated_at` — unique(student_id, iso_date, slot) |

`lesson_logs.sheets` เก็บชีทได้หลายแผ่นต่อคาบ: `[{name, video_done, pages_done, pages_total}, ...]` (มี CHECK บังคับว่าต้องเป็น array)

RLS เปิดบน `leave_requests`: admin เห็น/แก้ได้ทั้งหมด, viewer เข้าถึงเฉพาะของนักเรียนใน `student_ids` ตัวเอง (`= any(u.student_ids)`)

RLS เปิดบน `lesson_logs` เช่นกัน แต่**เข้มกว่า**: อ่านได้เหมือน `leave_requests` (admin ทั้งหมด / viewer เฉพาะ `student_ids`) ส่วน insert/update/delete **จำกัดที่ `role = 'admin'` เท่านั้น** — viewer เป็นผู้อ่านอย่างเดียว

---

## 4. ฟีเจอร์

### 4.1 จัดการตาราง (admin)
- Import CSV จาก Google Sheet (auto-detect เดือน/ปี, merge เข้าเดือนที่เลือก)
- เพิ่ม/แก้/ลบนักเรียน + กรอกตารางรายเดือนแบบ checkbox
- 3 มุมมอง: ตารางรายวัน, สรุปรายเดือนรายคน, heatmap จำนวนต่อช่วง
- Responsive: desktop = ตาราง, mobile = card + bottom nav + FAB

### 4.2 หน้า viewer (มือถือ)
- ผู้ปกครอง/นักเรียนที่ถูกผูก เห็นการ์ดตารางของลูก/ตัวเอง เลื่อนเดือนได้

### 4.3 ขอลา (leave request)
- **viewer แตะคาบเรียน → ขอลา** · กติกา: แจ้ง **≥2 วัน = อนุมัติอัตโนมัติ**, **<2 วัน = รอครูพิจารณา (pending)**, คาบที่ผ่านแล้ว = ลาไม่ได้
- **admin อนุมัติ/ปฏิเสธ** ในกล่อง "📋 คำขอลา" (แท็บจัดการผู้ใช้) + มีจุดแดงเตือน
- แสดงผล: คาบที่ลาอนุมัติ = **ขีดฆ่า + ป้าย "ลา"**, รออนุมัติ = "รอลา" · heatmap ไม่นับคนที่ลาอนุมัติแล้ว
- **ยกเลิกการลา:** viewer แตะคาบที่ลาแล้วซ้ำ → ปุ่ม "ยกเลิกการลา" · ยกเลิกเองได้ถ้าเหลือ **≥2 วัน**, <2 วัน ต้องแจ้งครู

### 4.4 ลงทะเบียนต้องตั้งชื่อผู้ใช้
- ฟอร์มสมัครบังคับกรอก **ชื่อผู้ใช้/ชื่อจริง** (`display_name`) → admin เห็นตอนอนุมัติ · ชื่อ escape กัน XSS

### 4.7 บันทึกการเรียน (lesson log)
- เก็บ **รายคาบ** — 1 แถว = (นักเรียน, วันที่, ช่วงเวลา) → มีประวัติครบ และคำนวณ "ล่าสุดที่เรียน" ของแต่ละคนได้
- **สิ่งที่บันทึกต่อคาบ:** เวลาเข้า-เลิกเรียน · ชีทหลายแผ่น (ชื่อชีท + ติ๊กวิดิโอจบ + โจทย์ ทำได้/ทั้งหมด กี่หน้า) · การบ้าน · ความเห็นจากผู้สอน
- **เวลาเข้า-เลิก** เติมเวลาของคาบมาให้ก่อน (M13 → 13:00/15:00) ครูแก้เฉพาะตอนนักเรียนมาสาย/กลับก่อน · มี validate ว่าเวลาเลิกต้องไม่ก่อนเวลาเข้า
- **ครูบันทึก 2 ทาง:** (ก) แตะไอคอน 📝 บนชิปนักเรียนในตารางเรียน (แตะที่ตัวชิปยังเปิดหน้าแก้นักเรียนเหมือนเดิม — ใช้ `stopPropagation`) (ข) แท็บ **"📘 บันทึกการเรียน"** — จัดกลุ่มตามนักเรียน ป้าย "ล่าสุด" ที่คาบใหม่สุด + ค้นหาด้วยชื่อ/ชีท/การบ้าน/ความเห็น
- ชิปที่มีบันทึกแล้วขีดเส้นใต้สีเขียว · ล้างจนว่างหมด (ทั้งชีท+การบ้าน+ความเห็น) แล้วกดบันทึก = ลบบันทึกคาบนั้น
- **viewer เห็นอย่างเดียว (แต่เห็นครบทุกช่อง):** กล่อง "📘 ล่าสุดที่เรียน" บนหัวการ์ดนักเรียน (query แยก `limit 1` ต่อคน จึงข้ามเดือนได้) + บรรทัดรายละเอียดใต้คาบที่มีบันทึก + จุดเขียวบนคาบนั้น
- ข้อความที่ครูพิมพ์ทั้งหมด render ผ่าน `escHtml()` (กัน XSS) และคงบรรทัดใหม่ด้วย CSS `white-space:pre-wrap` (ไม่แปลงเป็น `<br>` เพื่อไม่ให้ markup กลับเข้ามา)

### 4.5 ลืมรหัสผ่าน
- ลิงก์ "ลืมรหัสผ่าน?" → `resetPasswordForEmail` ส่งอีเมล → คลิกลิงก์กลับมา (`PASSWORD_RECOVERY`) → ตั้งรหัสใหม่ (`updateUser`)

### 4.6 แจ้งเตือน LINE เมื่อมีคนลา
- Postgres trigger + `pg_net` ยิงตรงไป **LINE Messaging API** ตอนมีแถวใหม่ใน `leave_requests` (LINE Notify ปิดบริการแล้ว จึงใช้ Messaging API)
- ปัจจุบัน: **broadcast** หาทุกคนที่แอด OA, แจ้งทุกครั้งที่ลา

---

## 5. ไฟล์ SQL / migration (รันใน Supabase SQL Editor)

| ไฟล์ | หน้าที่ | สถานะ |
|---|---|---|
| `supabase-leave-migration.sql` | สร้าง `leave_requests` + RLS (ใช้ `student_ids`) | ✅ รันแล้ว |
| `supabase-username-migration.sql` | เพิ่มคอลัมน์ `display_name` | ✅ รันแล้ว |
| `supabase-line-notify.sql` | trigger + pg_net แจ้ง LINE (**มี token — gitignore ไว้**) | ✅ รันแล้ว |
| `supabase-lesson-log-migration.sql` | **v2** — `lesson_logs` (เวลา/ชีท jsonb/ความเห็นครู) + RLS (admin เขียน / viewer อ่าน) · อัปเกรดจาก v1 ให้เอง (ย้าย `content` → ชีทแผ่นแรก แล้ว drop) | ✅ รันแล้ว |

> ⚠️ `supabase-line-notify.sql` มี LINE Channel Access Token → ถูก `.gitignore` ไว้ **ห้าม commit ขึ้น repo**

---

## 6. ตั้งค่า Supabase ที่ต้องมี

- **Authentication → URL Configuration** (สำหรับลืมรหัสผ่าน): Site URL + Redirect URLs = `https://sapiens091141.github.io/HB-schedule/**`
- `mailer_autoconfirm: true` (สมัครแล้วใช้ได้ทันที ไม่ต้องยืนยันอีเมล)
- Extension **`pg_net`** เปิด (สำหรับแจ้ง LINE)
- รีเซ็ตรหัสผ่านผู้ใช้ต้องทำใน Dashboard → Authentication → Users (anon key ทำไม่ได้)

---

## 7. หมายเหตุการพัฒนา (gotchas)

- **แก้จากโฟลเดอร์นี้เท่านั้น** — เป็น clone จริงของ repo (เคยมีไฟล์เก่า 51KB ค้างในเครื่องที่ไม่ตรงกับตัวจริง 87KB มาก่อน)
- ไฟล์เก็บเป็น **LF** (git `autocrlf=true` → repo เก็บ LF, checkout เป็น CRLF) — warning "LF will be replaced by CRLF" ไม่เป็นไร
- **`index.html` ไม่มี YAML front matter** + มี `.nojekyll` → GitHub Pages เสิร์ฟไฟล์ตรงๆ ไม่ผ่าน Jekyll
- Debug LINE: `select status_code, content from net._http_response order by created desc limit 5;`

---

## 8. Changelog (งานที่ทำ 2026-07-04)

| commit | งาน |
|---|---|
| `8fa286f` | ฟีเจอร์ขอลา + กติกา 2 วัน + admin อนุมัติ (บนโมเดล `student_ids`) |
| `cd3f8b6` | บังคับตั้งชื่อผู้ใช้ตอนลงทะเบียน (`display_name`) |
| `6c90016` | ลืมรหัสผ่าน / ตั้งรหัสใหม่ |
| `fa58877` | gitignore ไฟล์ LINE notify (กัน token หลุด) |
| `44c0f41` | กติกา 2 วัน สำหรับยกเลิกการลาเอง |
| `86b10bc` | เพิ่ม hint ให้หาปุ่มยกเลิกการลาเจอ |
| `8fb3632` | เพิ่ม `.nojekyll` กัน Pages build ล้ม |

## 9. Changelog (2026-08-27)

| งาน | รายละเอียด |
|---|---|
| ฟีเจอร์บันทึกการเรียน | ตาราง `lesson_logs` (รายคาบ) + modal 📝 บนชิปตารางเรียน + แท็บที่ 5 "บันทึกการเรียน" + กล่อง "ล่าสุดที่เรียน" ในหน้า viewer · ดู §4.7 |
| ขยายเป็น v2 | เพิ่มเวลาเข้า-เลิกเรียน, ชีทหลายแผ่น (ชื่อ/วิดิโอจบ/โจทย์กี่หน้า), ความเห็นจากผู้สอน · ตัดช่อง `content` ทิ้ง ใช้ชื่อชีทแทน |
