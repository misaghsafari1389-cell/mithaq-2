# راهنمای پشتیبان‌گیری و نگهداری

از Supabase Dashboard به‌صورت دوره‌ای از Database backup و Storage export استفاده کنید. migration موجود در `supabase/migrations/` باید در کنار نسخه repository نگهداری شود. پیش از هر migration جدید، ابتدا روی محیط جداگانه یا snapshot آزمایش کنید.

فایل‌های bucket `mithaq-attachments` خصوصی هستند؛ لینک‌های signed موقت‌اند و نباید در گزارش‌ها ذخیره شوند. حساب مدیران باید MFA و گذرواژه یکتا داشته باشد و مدیران غیرفعال از جدول `mithaq_admin_roles` حذف دسترسی شوند.
