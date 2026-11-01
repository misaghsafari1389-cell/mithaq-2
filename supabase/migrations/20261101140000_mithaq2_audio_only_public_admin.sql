-- Audio-only public form and explicitly public manager panel.
-- Existing Mithaq 2 tables and historical data are preserved.

alter table public.mithaq_report_notes alter column author_id drop not null;

create or replace function public.mithaq_submit_audio_report(
  p_title text,
  p_urgency text
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
  if p_urgency not in ('عادی', 'ضروری', 'فوری') then
    raise exception 'سطح فوریت نامعتبر است';
  end if;
  v_id := gen_random_uuid();
  v_tracking := 'M2-' || upper(substr(encode(extensions.gen_random_bytes(6), 'hex'), 1, 10));
  v_token := encode(extensions.gen_random_bytes(24), 'hex');
  insert into public.mithaq_reports(id, tracking_code, title, topic, occurred_at, location, upload_token)
  values (v_id, v_tracking, trim(p_title), p_urgency, now(), 'ثبت صوتی سامانه', v_token);
  insert into public.mithaq_report_private(report_id, description)
  values (v_id, 'گزارش صوتی سامانه میثاق ۲');
  insert into public.mithaq_report_status_history(report_id, from_status, to_status)
  values (v_id, null, 'new');
  return query select v_id, v_tracking, v_token;
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
declare v_from text;
begin
  if p_status not in ('new', 'investigating', 'needs_info', 'completed', 'archived') then raise exception 'وضعیت نامعتبر است'; end if;
  select status into v_from from public.mithaq_reports where id = p_report_id for update;
  if v_from is null then raise exception 'گزارش پیدا نشد'; end if;
  update public.mithaq_reports set status = p_status, is_read = true where id = p_report_id;
  insert into public.mithaq_report_status_history(report_id, from_status, to_status, changed_by, note)
  values (p_report_id, v_from, p_status, auth.uid(), nullif(trim(coalesce(p_note, '')), ''));
  return true;
end;
$$;

create or replace function public.mithaq_mark_report_read(p_report_id uuid)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
begin update public.mithaq_reports set is_read = true where id = p_report_id; return found; end;
$$;

create or replace function public.mithaq_add_note(p_report_id uuid, p_body text)
returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare v_id uuid;
begin
  if length(trim(coalesce(p_body, ''))) not between 1 and 4000 then raise exception 'یادداشت نامعتبر است'; end if;
  insert into public.mithaq_report_notes(report_id, author_id, body)
  values (p_report_id, auth.uid(), trim(p_body)) returning id into v_id;
  return v_id;
end;
$$;

grant select on table public.mithaq_reports, public.mithaq_report_private, public.mithaq_report_attachments,
  public.mithaq_report_notes, public.mithaq_report_status_history to anon;
grant execute on function public.mithaq_submit_audio_report(text, text) to anon;
grant execute on function public.mithaq_update_report_status(uuid, text, text) to anon;
grant execute on function public.mithaq_mark_report_read(uuid) to anon;
grant execute on function public.mithaq_add_note(uuid, text) to anon;

create policy mithaq_public_read_reports on public.mithaq_reports for select to anon using (true);
create policy mithaq_public_read_private on public.mithaq_report_private for select to anon using (true);
create policy mithaq_public_read_attachments on public.mithaq_report_attachments for select to anon using (true);
create policy mithaq_public_read_notes on public.mithaq_report_notes for select to anon using (true);
create policy mithaq_public_read_history on public.mithaq_report_status_history for select to anon using (true);

create policy mithaq_public_storage_read on storage.objects for select to anon
using (bucket_id = 'mithaq-attachments');

notify pgrst, 'reload schema';
