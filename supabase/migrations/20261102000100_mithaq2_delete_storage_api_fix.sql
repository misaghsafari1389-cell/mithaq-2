-- Supabase Storage objects must be removed through the Storage API, not storage.objects SQL.
create or replace function public.mithaq_delete_report(p_report_id uuid, p_upload_token text)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_token text;
begin
  select upload_token into v_token from public.mithaq_reports where id=p_report_id for update;
  if v_token is null or v_token<>p_upload_token then raise exception 'شناسه حذف گزارش معتبر نیست'; end if;
  delete from public.mithaq_reports where id=p_report_id;
  return found;
end;
$$;
grant execute on function public.mithaq_delete_report(uuid,text) to anon;
notify pgrst,'reload schema';
