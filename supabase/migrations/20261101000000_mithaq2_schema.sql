-- Mithaq 2 additive schema. Existing project tables are intentionally untouched.

create extension if not exists pgcrypto;

create table public.mithaq_reports (
  id uuid primary key default gen_random_uuid(),
  tracking_code text not null unique,
  title text not null check (char_length(trim(title)) between 3 and 180),
  topic text not null check (char_length(trim(topic)) between 2 and 80),
  occurred_at timestamptz not null,
  location text not null check (char_length(trim(location)) between 2 and 240),
  status text not null default 'new' check (status in ('new', 'investigating', 'needs_info', 'completed', 'archived')),
  is_read boolean not null default false,
  upload_token text not null unique check (char_length(upload_token) >= 24),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.mithaq_report_private (
  report_id uuid primary key references public.mithaq_reports(id) on delete cascade,
  description text not null check (char_length(trim(description)) between 10 and 10000),
  people_related text check (people_related is null or char_length(people_related) <= 4000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.mithaq_report_attachments (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.mithaq_reports(id) on delete cascade,
  storage_path text not null unique,
  file_name text not null check (char_length(file_name) between 1 and 255),
  mime_type text not null check (mime_type in ('image/jpeg', 'image/png', 'image/webp', 'image/gif', 'audio/webm', 'audio/ogg', 'audio/mp4', 'audio/mpeg', 'audio/wav')),
  size_bytes bigint not null check (size_bytes > 0 and size_bytes <= 26214400),
  kind text not null check (kind in ('image', 'audio')),
  created_at timestamptz not null default now()
);

create table public.mithaq_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 1 and 120),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.mithaq_admin_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'admin' check (role in ('admin', 'super_admin')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.mithaq_report_notes (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.mithaq_reports(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete restrict,
  body text not null check (char_length(trim(body)) between 1 and 4000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.mithaq_report_status_history (
  id bigint generated always as identity primary key,
  report_id uuid not null references public.mithaq_reports(id) on delete cascade,
  from_status text check (from_status is null or from_status in ('new', 'investigating', 'needs_info', 'completed', 'archived')),
  to_status text not null check (to_status in ('new', 'investigating', 'needs_info', 'completed', 'archived')),
  changed_by uuid references auth.users(id) on delete set null,
  note text check (note is null or char_length(note) <= 4000),
  created_at timestamptz not null default now()
);

create index mithaq_reports_status_created_idx on public.mithaq_reports(status, created_at desc);
create index mithaq_reports_unread_idx on public.mithaq_reports(is_read, created_at desc);
create index mithaq_reports_topic_idx on public.mithaq_reports(topic);
create index mithaq_report_attachments_report_idx on public.mithaq_report_attachments(report_id, created_at);
create index mithaq_report_notes_report_idx on public.mithaq_report_notes(report_id, created_at desc);
create index mithaq_status_history_report_idx on public.mithaq_report_status_history(report_id, created_at desc);

create or replace function public.mithaq_touch_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger mithaq_reports_touch_updated_at before update on public.mithaq_reports
for each row execute function public.mithaq_touch_updated_at();
create trigger mithaq_report_private_touch_updated_at before update on public.mithaq_report_private
for each row execute function public.mithaq_touch_updated_at();
create trigger mithaq_profiles_touch_updated_at before update on public.mithaq_profiles
for each row execute function public.mithaq_touch_updated_at();
create trigger mithaq_admin_roles_touch_updated_at before update on public.mithaq_admin_roles
for each row execute function public.mithaq_touch_updated_at();
create trigger mithaq_report_notes_touch_updated_at before update on public.mithaq_report_notes
for each row execute function public.mithaq_touch_updated_at();

create or replace function public.mithaq_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.mithaq_admin_roles
    where user_id = (select auth.uid()) and is_active = true
  );
$$;

create or replace function public.mithaq_upload_token_exists(p_token text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (select 1 from public.mithaq_reports where upload_token = p_token);
$$;

create or replace function public.mithaq_submit_report(
  p_title text,
  p_topic text,
  p_occurred_at timestamptz,
  p_location text,
  p_description text,
  p_people_related text default null
)
returns table(report_id uuid, tracking_code text, upload_token text)
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_id uuid;
  v_tracking text;
  v_token text;
begin
  if length(trim(coalesce(p_title, ''))) not between 3 and 180 then
    raise exception 'عنوان گزارش باید بین ۳ تا ۱۸۰ نویسه باشد';
  end if;
  if length(trim(coalesce(p_topic, ''))) not between 2 and 80 then
    raise exception 'موضوع گزارش نامعتبر است';
  end if;
  if p_occurred_at is null then
    raise exception 'زمان وقوع الزامی است';
  end if;
  if length(trim(coalesce(p_location, ''))) not between 2 and 240 then
    raise exception 'محل وقوع نامعتبر است';
  end if;
  if length(trim(coalesce(p_description, ''))) not between 10 and 10000 then
    raise exception 'شرح واقعه باید بین ۱۰ تا ۱۰۰۰۰ نویسه باشد';
  end if;
  if length(coalesce(p_people_related, '')) > 4000 then
    raise exception 'اطلاعات افراد مرتبط بیش از حد مجاز است';
  end if;

  v_id := gen_random_uuid();
  v_tracking := 'M2-' || upper(substr(encode(extensions.gen_random_bytes(6), 'hex'), 1, 10));
  v_token := encode(extensions.gen_random_bytes(24), 'hex');

  insert into public.mithaq_reports(id, tracking_code, title, topic, occurred_at, location, upload_token)
  values (v_id, v_tracking, trim(p_title), trim(p_topic), p_occurred_at, trim(p_location), v_token);

  insert into public.mithaq_report_private(report_id, description, people_related)
  values (v_id, trim(p_description), nullif(trim(coalesce(p_people_related, '')), ''));

  insert into public.mithaq_report_status_history(report_id, from_status, to_status)
  values (v_id, null, 'new');

  return query select v_id, v_tracking, v_token;
end;
$$;

create or replace function public.mithaq_register_attachment(
  p_upload_token text,
  p_path text,
  p_file_name text,
  p_mime_type text,
  p_size_bytes bigint,
  p_kind text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_report_id uuid;
  v_id uuid;
  v_clean_name text;
begin
  select id into v_report_id from public.mithaq_reports where upload_token = p_upload_token;
  if v_report_id is null then raise exception 'شناسه بارگذاری معتبر نیست'; end if;
  if split_part(p_path, '/', 1) <> p_upload_token then raise exception 'مسیر فایل نامعتبر است'; end if;
  if p_mime_type not in ('image/jpeg', 'image/png', 'image/webp', 'image/gif', 'audio/webm', 'audio/ogg', 'audio/mp4', 'audio/mpeg', 'audio/wav') then raise exception 'نوع فایل مجاز نیست'; end if;
  if p_size_bytes <= 0 or p_size_bytes > 26214400 then raise exception 'حجم فایل مجاز نیست'; end if;
  if p_kind not in ('image', 'audio') then raise exception 'دسته فایل نامعتبر است'; end if;
  if p_kind = 'image' and p_mime_type not like 'image/%' then raise exception 'نوع تصویر نامعتبر است'; end if;
  if p_kind = 'audio' and p_mime_type not like 'audio/%' then raise exception 'نوع صوت نامعتبر است'; end if;
  v_clean_name := regexp_replace(coalesce(p_file_name, 'attachment'), '[^a-zA-Z0-9._-]+', '-', 'g');
  insert into public.mithaq_report_attachments(report_id, storage_path, file_name, mime_type, size_bytes, kind)
  values (v_report_id, p_path, left(v_clean_name, 255), p_mime_type, p_size_bytes, p_kind)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.mithaq_remove_attachment(p_upload_token text, p_path text)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  delete from public.mithaq_report_attachments
  where storage_path = p_path
    and report_id in (select id from public.mithaq_reports where upload_token = p_upload_token);
  return found;
end;
$$;

create or replace function public.mithaq_update_report_status(
  p_report_id uuid,
  p_status text,
  p_note text default null
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_from text;
begin
  if not public.mithaq_is_admin() then raise exception 'دسترسی مدیر لازم است'; end if;
  if p_status not in ('new', 'investigating', 'needs_info', 'completed', 'archived') then raise exception 'وضعیت نامعتبر است'; end if;
  select status into v_from from public.mithaq_reports where id = p_report_id for update;
  if v_from is null then raise exception 'گزارش پیدا نشد'; end if;
  update public.mithaq_reports
  set status = p_status, is_read = true
  where id = p_report_id;
  insert into public.mithaq_report_status_history(report_id, from_status, to_status, changed_by, note)
  values (p_report_id, v_from, p_status, auth.uid(), nullif(trim(coalesce(p_note, '')), ''));
  return true;
end;
$$;

create or replace function public.mithaq_mark_report_read(p_report_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.mithaq_is_admin() then raise exception 'دسترسی مدیر لازم است'; end if;
  update public.mithaq_reports set is_read = true where id = p_report_id;
  return found;
end;
$$;

create or replace function public.mithaq_add_note(p_report_id uuid, p_body text)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id uuid;
begin
  if not public.mithaq_is_admin() then raise exception 'دسترسی مدیر لازم است'; end if;
  if length(trim(coalesce(p_body, ''))) not between 1 and 4000 then raise exception 'یادداشت نامعتبر است'; end if;
  insert into public.mithaq_report_notes(report_id, author_id, body)
  values (p_report_id, auth.uid(), trim(p_body))
  returning id into v_id;
  return v_id;
end;
$$;

-- Remove broad default exposure and grant only the operations used by the browser.
revoke all on table public.mithaq_reports, public.mithaq_report_private, public.mithaq_report_attachments,
  public.mithaq_profiles, public.mithaq_admin_roles, public.mithaq_report_notes, public.mithaq_report_status_history
from anon, authenticated;
grant select on table public.mithaq_reports, public.mithaq_report_private, public.mithaq_report_attachments,
  public.mithaq_profiles, public.mithaq_admin_roles, public.mithaq_report_notes, public.mithaq_report_status_history
to authenticated;

grant execute on function public.mithaq_submit_report(text, text, timestamptz, text, text, text) to anon, authenticated;
grant execute on function public.mithaq_register_attachment(text, text, text, text, bigint, text) to anon, authenticated;
grant execute on function public.mithaq_remove_attachment(text, text) to anon, authenticated;
grant execute on function public.mithaq_update_report_status(uuid, text, text) to authenticated;
grant execute on function public.mithaq_mark_report_read(uuid) to authenticated;
grant execute on function public.mithaq_add_note(uuid, text) to authenticated;
revoke all on function public.mithaq_is_admin() from public, anon, authenticated;
grant execute on function public.mithaq_is_admin() to authenticated;
revoke all on function public.mithaq_upload_token_exists(text) from public, anon, authenticated;
grant execute on function public.mithaq_upload_token_exists(text) to anon, authenticated;
revoke all on function public.mithaq_touch_updated_at() from public, anon, authenticated;

alter table public.mithaq_reports enable row level security;
alter table public.mithaq_report_private enable row level security;
alter table public.mithaq_report_attachments enable row level security;
alter table public.mithaq_profiles enable row level security;
alter table public.mithaq_admin_roles enable row level security;
alter table public.mithaq_report_notes enable row level security;
alter table public.mithaq_report_status_history enable row level security;

create policy mithaq_admin_read_reports on public.mithaq_reports for select to authenticated
using ((select public.mithaq_is_admin()));
create policy mithaq_admin_update_reports on public.mithaq_reports for update to authenticated
using ((select public.mithaq_is_admin())) with check ((select public.mithaq_is_admin()));
create policy mithaq_admin_read_private on public.mithaq_report_private for select to authenticated
using ((select public.mithaq_is_admin()));
create policy mithaq_admin_read_attachments on public.mithaq_report_attachments for select to authenticated
using ((select public.mithaq_is_admin()));
create policy mithaq_admin_read_profiles on public.mithaq_profiles for select to authenticated
using ((select public.mithaq_is_admin()));
create policy mithaq_admin_read_roles on public.mithaq_admin_roles for select to authenticated
using ((select public.mithaq_is_admin()));
create policy mithaq_admin_read_notes on public.mithaq_report_notes for select to authenticated
using ((select public.mithaq_is_admin()));
create policy mithaq_admin_read_history on public.mithaq_report_status_history for select to authenticated
using ((select public.mithaq_is_admin()));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('mithaq-attachments', 'mithaq-attachments', false, 26214400,
  array['image/jpeg','image/png','image/webp','image/gif','audio/webm','audio/ogg','audio/mp4','audio/mpeg','audio/wav'])
on conflict (id) do update set public = false, file_size_limit = 26214400,
  allowed_mime_types = excluded.allowed_mime_types;

create policy mithaq_admin_storage_read on storage.objects for select to authenticated
using (bucket_id = 'mithaq-attachments' and (select public.mithaq_is_admin()));
create policy mithaq_public_storage_insert on storage.objects for insert to anon, authenticated
with check (
  bucket_id = 'mithaq-attachments'
  and public.mithaq_upload_token_exists(split_part(name, '/', 1))
  and lower(storage.extension(name)) in ('jpg','jpeg','png','webp','gif','webm','ogg','mp4','mpeg','wav')
  and octet_length(name) <= 512
);
create policy mithaq_public_storage_delete on storage.objects for delete to anon, authenticated
using (
  bucket_id = 'mithaq-attachments'
  and public.mithaq_upload_token_exists(split_part(name, '/', 1))
);

alter publication supabase_realtime add table public.mithaq_reports;

-- The browser-facing RPCs are intentionally the only anonymous write path.
revoke insert, update, delete, select on table public.mithaq_reports, public.mithaq_report_private,
  public.mithaq_report_attachments, public.mithaq_profiles, public.mithaq_admin_roles,
  public.mithaq_report_notes, public.mithaq_report_status_history from anon;
