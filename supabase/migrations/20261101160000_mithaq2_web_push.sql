-- Web Push subscriptions for the opted-in manager device.
-- The subscription endpoint is stored without a user account because the chosen admin panel has no login.
alter table public.mithaq_reports add column if not exists push_notified_at timestamptz;
create table if not exists public.mithaq_push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  endpoint text not null unique check (char_length(endpoint) between 20 and 2048),
  p256dh text not null check (char_length(p256dh) between 20 and 256),
  auth text not null check (char_length(auth) between 10 and 256),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);
alter table public.mithaq_push_subscriptions enable row level security;
revoke all on table public.mithaq_push_subscriptions from anon, authenticated;
create or replace function public.mithaq_save_push_subscription(p_endpoint text,p_p256dh text,p_auth text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_id uuid;
begin
  if p_endpoint !~ '^https://' then raise exception 'نشانی اعلان نامعتبر است'; end if;
  if length(p_endpoint) not between 20 and 2048 or length(p_p256dh) not between 20 and 256 or length(p_auth) not between 10 and 256 then raise exception 'اشتراک اعلان نامعتبر است'; end if;
  insert into public.mithaq_push_subscriptions(endpoint,p256dh,auth,last_seen_at)
  values(p_endpoint,p_p256dh,p_auth,now())
  on conflict(endpoint) do update set p256dh=excluded.p256dh,auth=excluded.auth,last_seen_at=now()
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.mithaq_save_push_subscription(text,text,text) from public,anon,authenticated;
grant execute on function public.mithaq_save_push_subscription(text,text,text) to anon,authenticated;
