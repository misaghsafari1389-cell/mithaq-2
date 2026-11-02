-- Optional report description and controlled permanent deletion.

alter table public.mithaq_report_private alter column description drop not null;
drop constraint if exists mithaq_report_private_description_check;
alter table public.mithaq_report_private add constraint mithaq_report_private_description_check
  check (description is null or char_length(trim(description)) between 1 and 10000);

create or replace function public.mithaq_submit_audio_report(
  p_title text,
  p_urgency text,
  p_description text default null
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
  v_description text := nullif(trim(coalesce(p_description, '')), '');
begin
  if length(trim(coalesce(p_title, ''))) not between 3 and 180 then
    raise exception 'عنوان گزارش باید بین ۳ تا ۱۸۰ نویسه باشد';
  end if;
  if p_urgency not in ('عادی', 'ضروری', 'فوری') then
    raise exception 'سطح فوریت نامعتبر است';
  end if;
  if v_description is not null and length(v_description) > 10000 then
    raise exception 'توضیحات بیش از حد مجاز است';
  end if;

  v_id := gen_random_uuid();
  v_tracking := 'M2-' || upper(substr(encode(extensions.gen_random_bytes(6), 'hex'), 1, 10));
  v_token := encode(extensions.gen_random_bytes(24), 'hex');

  insert into public.mithaq_reports(id, tracking_code, title, topic, occurred_at, location, upload_token)
  values (v_id, v_tracking, trim(p_title), p_urgency, now(), 'ثبت صوتی سامانه', v_token);
  insert into public.mithaq_report_private(report_id, description)
  values (v_id, v_description);
  insert into public.mithaq_report_status_history(report_id, from_status, to_status)
  values (v_id, null, 'new');
  return query select v_id, v_tracking, v_token;
end;
$$;

grant execute on function public.mithaq_submit_audio_report(text, text, text) to anon;

create or replace function public.mithaq_delete_report(
  p_report_id uuid,
  p_upload_token text
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_token text;
begin
  select upload_token into v_token
  from public.mithaq_reports
  where id = p_report_id
  for update;
  if v_token is null or v_token <> p_upload_token then
    raise exception 'شناسه حذف گزارش معتبر نیست';
  end if;

  delete from public.mithaq_reports where id = p_report_id;
  return found;
end;
$$;

grant execute on function public.mithaq_delete_report(uuid, text) to anon;

drop policy if exists mithaq_public_storage_delete on storage.objects;
create policy mithaq_public_storage_delete on storage.objects
for delete to anon
using (
  bucket_id = 'mithaq-attachments'
  and exists (
    select 1 from public.mithaq_reports r
    where r.upload_token = split_part(name, '/', 1)
  )
);

notify pgrst, 'reload schema';
