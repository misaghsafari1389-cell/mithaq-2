# میثاق ۲

سامانه فارسی RTL ثبت گزارش با سایت عمومی در `/` و پنل مدیریت در `/admin/`، متصل به Supabase Auth، PostgreSQL، Storage خصوصی و Realtime.

## راه‌اندازی

فایل browser-safe `js/config.js` شامل URL و publishable key است. هرگز Service Role Key را در کد عمومی قرار ندهید. migration `supabase/migrations/20261101000000_mithaq2_schema.sql` ساختار افزایشی، RPCها، RLS، bucket و publication را ایجاد می‌کند. ثبت‌نام عمومی مدیران وجود ندارد؛ نقش مدیر در `mithaq_admin_roles` نگهداری می‌شود.

## قابلیت‌ها

فرم عمومی فیلدهای کامل گزارش، چند تصویر، MediaRecorder واقعی با موج زنده، پیش‌نمایش، کد پیگیری و upload خصوصی را فراهم می‌کند. پنل مدیر ورود امن، آمار، فیلتر، جزئیات، فایل‌های signed موقت، status، یادداشت داخلی، تاریخچه و اعلان Realtime دارد.

## انتشار

این پروژه روی GitHub Pages منتشر شده است. لینک عمومی و پنل مدیریت در `LINKS.txt` ثبت شده‌اند. راهنمای backup در `docs/BACKUP.md` و وضعیت آزمایش در `docs/TEST-REPORT.md` ثبت شده است.

## امنیت

داده‌های گزارش برای anon قابل خواندن نیستند. تغییرات عمومی فقط از RPCهای محدود انجام می‌شود. bucket خصوصی است و Service Role Key در پروژه نیست.
